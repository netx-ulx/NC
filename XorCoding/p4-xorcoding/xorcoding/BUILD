COMPILE_DEPS = CORE_DEPS + [
    "//apps/p4-xorcoding/pipeconf:onos-apps-p4-xorcoding-pipeconf",
]

osgi_jar(
    deps = COMPILE_DEPS,
)

BUNDLES = [
    "//apps/p4-xorcoding/xorcoding:onos-apps-p4-xorcoding-xorcoding",
]

onos_app(
    app_name = "org.onosproject.p4xorcoding.xorcoding",
    category = "Traffic Engineering",
    description = "Provides forwarding between each pair of hosts via MyTunnel protocol",
    included_bundles = BUNDLES,
    required_apps = [
        "org.onosproject.p4xorcoding.pipeconf",
    ],
    title = "XorCoding App",
    url = "http://onosproject.org",
)
