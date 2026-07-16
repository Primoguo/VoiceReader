#!/usr/bin/env python3
"""Add knowledge base files to Xcode project"""
import re

filepath = '/Users/primo/CodeBuddy/Knowledge/Knowledge.xcodeproj/project.pbxproj'

with open(filepath, 'r') as f:
    content = f.read()

# UUID mapping
# FileRef IDs:
KE_ENTRY_REF   = "KE000001AAAA0001BBBB0001"
KE_CHAT_REF    = "KE000002AAAA0002BBBB0002"
KE_SVC_REF     = "KE000003AAAA0003BBBB0003"
KE_LIST_REF    = "KE000004AAAA0004BBBB0004"
KE_DETAIL_REF  = "KE000005AAAA0005BBBB0005"

# BuildFile IDs:
KE_ENTRY_BF    = "KE000006AAAA0006BBBB0006"
KE_CHAT_BF     = "KE000007AAAA0007BBBB0007"
KE_SVC_BF      = "KE000008AAAA0008BBBB0008"
KE_LIST_BF     = "KE000009AAAA0009BBBB0009"
KE_DETAIL_BF   = "KE000010AAAA0010BBBB0010"

# 1. Add PBXFileReference entries (after CompanionChat.swift reference)
new_filerefs = f"""		{KE_ENTRY_REF} /* KnowledgeEntry.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KnowledgeEntry.swift; sourceTree = "<group>"; }};
		{KE_CHAT_REF} /* KnowledgeChat.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KnowledgeChat.swift; sourceTree = "<group>"; }};
		{KE_SVC_REF} /* KnowledgeService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KnowledgeService.swift; sourceTree = "<group>"; }};
		{KE_LIST_REF} /* KnowledgeListView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KnowledgeListView.swift; sourceTree = "<group>"; }};
		{KE_DETAIL_REF} /* KnowledgeDetailView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = KnowledgeDetailView.swift; sourceTree = "<group>"; }};
"""

# Insert after CompanionChat.swift FileReference
anchor = 'CC112233445566778899CCDD /* CompanionChat.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CompanionChat.swift; sourceTree = "<group>"; };'
content = content.replace(anchor, anchor + '\n' + new_filerefs.rstrip())

# 2. Add PBXBuildFile entries (after CompanionChat.swift build file)
new_buildfiles = f"""		{KE_ENTRY_BF} /* KnowledgeEntry.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {KE_ENTRY_REF} /* KnowledgeEntry.swift */; }};
		{KE_CHAT_BF} /* KnowledgeChat.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {KE_CHAT_REF} /* KnowledgeChat.swift */; }};
		{KE_SVC_BF} /* KnowledgeService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {KE_SVC_REF} /* KnowledgeService.swift */; }};
		{KE_LIST_BF} /* KnowledgeListView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {KE_LIST_REF} /* KnowledgeListView.swift */; }};
		{KE_DETAIL_BF} /* KnowledgeDetailView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {KE_DETAIL_REF} /* KnowledgeDetailView.swift */; }};
"""

anchor2 = 'CC112233445566778899AABB /* CompanionChat.swift in Sources */ = {isa = PBXBuildFile; fileRef = CC112233445566778899CCDD /* CompanionChat.swift */; };'
content = content.replace(anchor2, anchor2 + '\n' + new_buildfiles.rstrip())

# 3. Add to Models group (after CompanionChat.swift)
content = content.replace(
    'CC112233445566778899CCDD /* CompanionChat.swift */,',
    f'CC112233445566778899CCDD /* CompanionChat.swift */,\n\t\t\t\t{KE_ENTRY_REF} /* KnowledgeEntry.swift */,\n\t\t\t\t{KE_CHAT_REF} /* KnowledgeChat.swift */,'
)

# 4. Add to Services group (after CompanionService.swift)
# Find CompanionService.swift in the Services group children
content = content.replace(
    '5C2B39403ADD46268C168655 /* AudioCacheService.swift */,',
    f'5C2B39403ADD46268C168655 /* AudioCacheService.swift */,\n\t\t\t\t{KE_SVC_REF} /* KnowledgeService.swift */,'
)

# 5. Add to Views group (after CompanionView.swift)
# Find CompanionView.swift in Views group children
content = content.replace(
    'A509AEA20935F1364E7F0687 /* LycheeMascotView.swift */,',
    f'A509AEA20935F1364E7F0687 /* LycheeMascotView.swift */,\n\t\t\t\t{KE_LIST_REF} /* KnowledgeListView.swift */,\n\t\t\t\t{KE_DETAIL_REF} /* KnowledgeDetailView.swift */,'
)

# 6. Add to Sources build phase (after CompanionChat.swift in Sources)
content = content.replace(
    'CC112233445566778899AABB /* CompanionChat.swift in Sources */,',
    f'CC112233445566778899AABB /* CompanionChat.swift in Sources */,\n\t\t\t\t{KE_ENTRY_BF} /* KnowledgeEntry.swift in Sources */,\n\t\t\t\t{KE_CHAT_BF} /* KnowledgeChat.swift in Sources */,\n\t\t\t\t{KE_SVC_BF} /* KnowledgeService.swift in Sources */,\n\t\t\t\t{KE_LIST_BF} /* KnowledgeListView.swift in Sources */,\n\t\t\t\t{KE_DETAIL_BF} /* KnowledgeDetailView.swift in Sources */,'
)

with open(filepath, 'w') as f:
    f.write(content)

# Verify
with open(filepath, 'r') as f:
    verify = f.read()

print(f"Lines: {len(verify.splitlines())}")
print(f"KnowledgeEntry count: {verify.count('KnowledgeEntry')}")
print(f"KnowledgeChat count: {verify.count('KnowledgeChat')}")
print(f"KnowledgeService count: {verify.count('KnowledgeService')}")
print(f"KnowledgeListView count: {verify.count('KnowledgeListView')}")
print(f"KnowledgeDetailView count: {verify.count('KnowledgeDetailView')}")
print("Done!")
