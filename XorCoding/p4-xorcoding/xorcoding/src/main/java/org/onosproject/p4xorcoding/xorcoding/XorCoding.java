/*
 * Copyright 2017-present Open Networking Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.onosproject.p4xorcoding.xorcoding;

import org.apache.felix.scr.annotations.Activate;
import org.apache.felix.scr.annotations.Component;
import org.apache.felix.scr.annotations.Deactivate;
import org.apache.felix.scr.annotations.Reference;
import org.apache.felix.scr.annotations.ReferenceCardinality;
import org.onosproject.core.ApplicationId;
import org.onosproject.core.CoreService;
import org.onosproject.net.*;
import org.onosproject.net.device.DeviceEvent;
import org.onosproject.net.device.DeviceListener;
import org.onosproject.net.device.DeviceService;
import org.onosproject.net.flow.DefaultFlowRule;
import org.onosproject.net.flow.DefaultTrafficSelector;
import org.onosproject.net.flow.DefaultTrafficTreatment;
import org.onosproject.net.flow.FlowRule;
import org.onosproject.net.flow.FlowRuleService;
import org.onosproject.net.flow.criteria.PiCriterion;
import org.onosproject.net.group.*;
import org.onosproject.net.host.HostService;
import org.onosproject.net.link.LinkService;
import org.onosproject.net.pi.model.PiActionId;
import org.onosproject.net.pi.model.PiActionParamId;
import org.onosproject.net.pi.model.PiMatchFieldId;
import org.onosproject.net.pi.model.PiTableId;
import org.onosproject.net.pi.runtime.PiAction;
import org.onosproject.net.pi.runtime.PiActionParam;
import org.onosproject.net.topology.PathService;
import org.onosproject.net.topology.TopologyService;
import org.onosproject.net.group.GroupDescription;
import org.slf4j.Logger;

import java.util.*;

import static org.slf4j.LoggerFactory.getLogger;

/**
 *
 */
@Component(immediate = true)
public class XorCoding {

    private static final String APP_NAME = "org.onosproject.p4rlnc.xorcoding";

    // Default priority used for flow rules installed by this app.
    private static final int FLOW_RULE_PRIORITY = 100;

    private final DeviceListener deviceListener = new InternalDeviceListener();
    private ApplicationId appId;

    private static final Logger log = getLogger(XorCoding.class);

    private static final long STORE_FLAG = 1;
    private static final long CODING_FLAG = 1;
    private static final long DECODING_FLAG = 1;
    private static final int MAX_DEVICES = 6;

    //--------------------------------------------------------------------------
    // ONOS services needed by this application.
    //--------------------------------------------------------------------------

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private FlowRuleService flowRuleService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private CoreService coreService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private TopologyService topologyService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private PathService pathService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private HostService hostService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private DeviceService deviceService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private LinkService linkService;

    @Reference(cardinality = ReferenceCardinality.MANDATORY_UNARY)
    private GroupService groupService;

    //--------------------------------------------------------------------------
    //--------------------------------------------------------------------------

    @Activate
    public void activate() {
        // Register app and event listeners.
        log.info("Starting...");
        appId = coreService.registerApplication(APP_NAME);
        deviceService.addListener(deviceListener);
        log.info("STARTED", appId.id());
    }

    @Deactivate
    public void deactivate() {
        // Remove listeners and clean-up flow rules.
        log.info("Stopping...");
        deviceService.removeListener(deviceListener);
        flowRuleService.removeFlowRulesById(appId);
        log.info("STOPPED");
    }

    /**
     * @param device
     */
    private void provisionForwarding(Device device) {


        //Multicast Switches
        if (device.toString().contains("s1") || device.toString().contains("s2") || device.toString().contains("s4")) {
            List<PortNumber> ports = new ArrayList<>();
            PortNumber ingressPort = PortNumber.portNumber(1);
            for (Port outPort : deviceService.getPorts(device.id())) {
                if (!outPort.number().equals(ingressPort)) {
                    ports.add(outPort.number());
                }
            }
            insertMulticastRule(device, ingressPort, ports, 1);
            //Unicast and Decoding Switches
        } else if (device.toString().contains("s5") || device.toString().contains("s6")) {
            PortNumber egressPort = PortNumber.portNumber(3);
            for (Port ingressPort : deviceService.getPorts(device.id())) {
                if (!ingressPort.number().equals(egressPort)) {
                    insertUnicastRule(device.id(), ingressPort.number(), egressPort);
                }
            }
            insertStorePayloadRule(device.id(), PortNumber.portNumber(1), STORE_FLAG);
            insertDecodingRule(device.id(), PortNumber.portNumber(2), DECODING_FLAG);
            //Unicast and Coding Switches
        } else if (device.toString().contains("s3")) {
            PortNumber egressPort = PortNumber.portNumber(3);
            for (Port ingressPort : deviceService.getPorts(device.id())) {
                if (!ingressPort.number().equals(egressPort)) {
                    insertUnicastRule(device.id(), ingressPort.number(), egressPort);
                    insertStorePayloadRule(device.id(), ingressPort.number(), STORE_FLAG);
                }
            }
            insertCodingRule(device.id(), CODING_FLAG);
        }
    }

    /**
     * @param switchId
     * @param inPort
     * @param storeFlag
     */
    private void insertStorePayloadRule(DeviceId switchId, PortNumber inPort, long storeFlag) {

        PiTableId storePayloadTableId = PiTableId.of("c_ingress.tab_store");

        PiMatchFieldId ingressPortMatchFieldId = PiMatchFieldId.of("standard_metadata.ingress_port");
        PiCriterion match = PiCriterion.builder()
                .matchExact(ingressPortMatchFieldId, (short) inPort.toLong())
                .build();

        PiActionParamId storeFlagParamId = PiActionParamId.of("store_flag");
        PiActionParam storeFlagParam = new PiActionParam(storeFlagParamId, (short) storeFlag);

        PiActionId ingressActionId = PiActionId.of("c_ingress.store");
        PiAction action = PiAction.builder()
                .withId(ingressActionId)
                .withParameter(storeFlagParam)
                .build();
        insertPiFlowRule(switchId, storePayloadTableId, match, action);
    }

    /**
     * @param switchId
     * @param codeFlag
     */
    private void insertCodingRule(DeviceId switchId, long codeFlag) {
        PiTableId codeTableId = PiTableId.of("c_ingress.tab_coding");

        long codeFlagMatchField = 0;
        PiMatchFieldId codeFlagMatchFieldId = PiMatchFieldId.of("meta.coding_metadata.coding_flag");
        PiCriterion match = PiCriterion.builder()
                .matchExact(codeFlagMatchFieldId, codeFlagMatchField)
                .build();

        PiActionParamId codeFlagParamId = PiActionParamId.of("coding_flag");
        PiActionParam codeFlagParam = new PiActionParam(codeFlagParamId, (short) codeFlag);


        PiActionId ingressActionId = PiActionId.of("c_ingress.coding");
        PiAction action = PiAction.builder()
                .withId(ingressActionId)
                .withParameter(codeFlagParam)
                .build();
        insertPiFlowRule(switchId, codeTableId, match, action);
    }

    /**
     * @param switchId
     * @param decodeFlag
     */
    private void insertDecodingRule(DeviceId switchId, PortNumber inPort, long decodeFlag) {
        PiTableId decodeTableId = PiTableId.of("c_ingress.tab_decoding");

        long type = 2;
        PiMatchFieldId ingressPortMatchFieldId = PiMatchFieldId.of("standard_metadata.ingress_port");
        PiMatchFieldId ingressTypeMatchFieldId = PiMatchFieldId.of("hdr.coding.type");
        PiCriterion match = PiCriterion.builder()
                .matchExact(ingressPortMatchFieldId, (short) inPort.toLong())
                .matchExact(ingressTypeMatchFieldId, (short) type)
                .build();

        PiActionParamId decodeFlagParamId = PiActionParamId.of("decoding_flag");
        PiActionParam decodeFlagParam = new PiActionParam(decodeFlagParamId, (short) decodeFlag);
        PiActionId ingressActionId = PiActionId.of("c_ingress.decoding");
        PiAction action = PiAction.builder()
                .withId(ingressActionId)
                .withParameter(decodeFlagParam)
                .build();
        insertPiFlowRule(switchId, decodeTableId, match, action);
    }

    /**
     * @param switchId
     * @param inPort
     * @param outPort
     */
    private void insertUnicastRule(DeviceId switchId, PortNumber inPort, PortNumber outPort) {


        PiTableId unicastIngressTableId = PiTableId.of("c_ingress.tab_unicast");

        PiMatchFieldId ingressPortMatchFieldId = PiMatchFieldId.of("standard_metadata.ingress_port");

        PiCriterion match = PiCriterion.builder()
                .matchExact(ingressPortMatchFieldId, (short) inPort.toLong())
                .build();

        PiActionParamId portParamId = PiActionParamId.of("port");
        PiActionParam portParam = new PiActionParam(portParamId, (short) outPort.toLong());


        PiActionId ingressActionId = PiActionId.of("c_ingress.set_out_port");
        PiAction action = PiAction.builder()
                .withId(ingressActionId)
                .withParameter(portParam)
                .build();

        insertPiFlowRule(switchId, unicastIngressTableId, match, action);

    }

    /**
     * @param sw
     * @param inPort
     * @param portNumbers
     * @param groupId
     */
    private void insertMulticastRule(Device sw, PortNumber inPort, List<PortNumber> portNumbers, int groupId) {


        GroupDescription groupDescription = createGroupDescription(portNumbers, groupId, sw);
        groupService.addGroup(groupDescription);


        PiTableId multicastIngressTableId = PiTableId.of("c_ingress.tab_multicast");


        PiMatchFieldId ingressPortMatchFieldId = PiMatchFieldId.of("standard_metadata.ingress_port");
        PiCriterion match = PiCriterion.builder()
                .matchExact(ingressPortMatchFieldId, (short) inPort.toLong())
                .build();

        PiActionParamId groupParamId = PiActionParamId.of("group");
        PiActionParam groupParam = new PiActionParam(groupParamId, groupId);


        PiActionId ingressActionId = PiActionId.of("c_ingress.multicast");
        PiAction action = PiAction.builder()
                .withId(ingressActionId)
                .withParameter(groupParam)
                .build();

        insertPiFlowRule(sw.id(), multicastIngressTableId, match, action);

    }


    /**
     * Inserts a flow rule in the system that using a PI criterion and action.
     *
     * @param switchId    switch ID
     * @param tableId     table ID
     * @param piCriterion PI criterion
     * @param piAction    PI action
     */
    private void insertPiFlowRule(DeviceId switchId, PiTableId tableId,
                                  PiCriterion piCriterion, PiAction piAction) {
        FlowRule rule = DefaultFlowRule.builder()
                .forDevice(switchId)
                .forTable(tableId)
                .fromApp(appId)
                .withPriority(FLOW_RULE_PRIORITY)
                .makePermanent()
                .withSelector(DefaultTrafficSelector.builder()
                        .matchPi(piCriterion).build())
                .withTreatment(DefaultTrafficTreatment.builder()
                        .piTableAction(piAction).build())
                .build();
        flowRuleService.applyFlowRules(rule);
    }


    /**
     * @param portNumbers
     * @param groupId
     * @param switchId
     * @return
     */
    private GroupDescription createGroupDescription(List<PortNumber> portNumbers, int groupId, Device switchId) {
        List<GroupBucket> bucketList = new ArrayList<>();
        for (PortNumber port : portNumbers) {
            bucketList.add(
                    DefaultGroupBucket.createAllGroupBucket(
                            DefaultTrafficTreatment.builder()
                                    .setOutput(port)
                                    .build()));

        }

        GroupBuckets groupBuckets = new GroupBuckets(bucketList);
        GroupKey groupKey = new DefaultGroupKey(Integer.toString(groupId).getBytes());

        GroupDescription groupDescription = new DefaultGroupDescription(switchId.id(), GroupDescription.Type.ALL, groupBuckets, groupKey, groupId, appId);

        return groupDescription;

    }

    /**
     *
     */
    private class InternalDeviceListener implements DeviceListener {


        @Override
        public void event(DeviceEvent event) {
            if (event.type() != DeviceEvent.Type.DEVICE_ADDED) {
                // Ignore other device events.
                return;
            }
            Device device = event.subject();
            if (device.type().equals(Device.Type.SWITCH)) {
                log.info("EVENT TRIGGERED={}", deviceService.getDeviceCount());
                provisionForwarding(device);
            }
        }
    }
}
