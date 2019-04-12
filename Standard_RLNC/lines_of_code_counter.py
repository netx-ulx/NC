#!/usr/bin/env python

# The original version of the script can be found here:
# https://github.com/rrwick/LinesOfCodeCounter

# This Python script counts the lines of code in a directory
# It only looks at files which end in the file extensions passed to the
# script as arguments.

# It outputs counts for total lines, blank lines, comment lines and code lines
# (total lines minus blank lines and comment lines).

# Example usage and output:
# > lines_of_code_counter.py .h .cpp
# Total lines:   15378
# Blank lines:   2945
# Comment lines: 1770
# Code lines:    10663

commentSymbol = "//"

import sys
import os, os.path

acceptableFileExtensions = sys.argv[1:]
if not acceptableFileExtensions:
    print 'Please pass at least one file extension as an argument.'
    quit()

dir = os.getcwd()
filesToCheck = []
for root, _, files in os.walk(dir):
    for f in files:
        fullpath = os.path.join(root, f)
        if '.git' not in fullpath and 'template' not in fullpath:
            for extension in acceptableFileExtensions:
            	if fullpath.endswith(extension):
                    filesToCheck.append(fullpath)

if not filesToCheck:
    print 'No files found.'
    quit()

lineCount = 0
totalBlankLineCount = 0
totalCommentLineCount = 0
linesBuffering = 0
linesForwarding = 0
linesPacketHeadersMetadata = 0
linesCoding = 0


print ''
print 'Filename\tlines\tblank\tcomment\tcode'

for fileToCheck in filesToCheck:
    with open(fileToCheck) as f:

        fileLineCount = 0
        fileBlankLineCount = 0
        fileCommentLineCount = 0

        for line in f:
            lineCount += 1
            fileLineCount += 1

            lineWithoutWhitespace = line.strip()
            if not lineWithoutWhitespace:
                totalBlankLineCount += 1
                fileBlankLineCount += 1
            elif lineWithoutWhitespace.startswith(commentSymbol):
                totalCommentLineCount += 1
                fileCommentLineCount += 1

        #if "ingress.p4" in fileToCheck or "registers.p4" in fileToCheck:
            #linesBuffering += fileLineCount - fileBlankLineCount - fileCommentLineCount

        #if "headers.p4" in fileToCheck or "metadata.p4" in fileToCheck:
            #linesPacketHeadersMetadata += fileLineCount - fileBlankLineCount - fileCommentLineCount

        if "egress.p4" in fileToCheck:
            linesCoding += fileLineCount - fileBlankLineCount - fileCommentLineCount
        print os.path.basename(fileToCheck) + \
              "\t" + str(fileLineCount) + \
              "\t" + str(fileBlankLineCount) + \
              "\t" + str(fileCommentLineCount) + \
              "\t" + str(fileLineCount - fileBlankLineCount - fileCommentLineCount)

"""
print ''
print 'Modules'
print '--------------------'
print 'Buffering:         ' + str(linesBuffering)
print 'Coding:            ' + str(linesCoding)
print 'Forwarding:        ' + str(linesForwarding)
print 'PacketHeaders:     ' + str(linesPacketHeadersMetadata)
"""

print ''
print 'Totals'
print '--------------------'
print 'Lines:         ' + str(lineCount)
print 'Blank lines:   ' + str(totalBlankLineCount)
print 'Comment lines: ' + str(totalCommentLineCount)
print 'Code lines:    ' + str(lineCount - totalBlankLineCount - totalCommentLineCount)
