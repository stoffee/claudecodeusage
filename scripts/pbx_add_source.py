#!/usr/bin/env python3
"""Register a Swift source file in ClaudeUsage.xcodeproj (ids are hand-numbered).

usage: scripts/pbx_add_source.py <build-id> <fileref-id> <path-from-repo-root>

Files under ClaudeUsage/ are added relative to the ClaudeUsage group. Anything
else (LanesCore/) is added relative to SOURCE_ROOT, so the app target compiles
it straight into the app module.
"""
import os
import sys

PBX = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..',
                   'ClaudeUsage.xcodeproj', 'project.pbxproj')

build_id, ref_id, rel = sys.argv[1:4]
name = os.path.basename(rel)
s = open(PBX).read()

for i in (build_id, ref_id):
    if f'\t\t{i} /*' in s:
        sys.exit(f'id {i} already in use')

if rel.startswith('ClaudeUsage/'):
    ref = (f'\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; '
           f'lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};\n')
else:
    ref = (f'\t\t{ref_id} /* {name} */ = {{isa = PBXFileReference; '
           f'lastKnownFileType = sourcecode.swift; name = {name}; path = {rel}; sourceTree = SOURCE_ROOT; }};\n')
build = f'\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};\n'


def insert_before(marker, text):
    global s
    if s.count(marker) != 1:
        sys.exit(f'marker not unique: {marker!r}')
    s = s.replace(marker, text + marker)


insert_before('/* End PBXBuildFile section */', build)
insert_before('/* End PBXFileReference section */', ref)
insert_before('\t\t\t\t104 /* Assets.xcassets */,\n', f'\t\t\t\t{ref_id} /* {name} */,\n')
insert_before('\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase section */',
              f'\t\t\t\t{build_id} /* {name} in Sources */,\n')

open(PBX, 'w').write(s)
print(f'registered {rel} as {build_id}/{ref_id}')
