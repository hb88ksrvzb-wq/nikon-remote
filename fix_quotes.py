import re

with open("generate_docx.py", "r", encoding="utf-8") as f:
    content = f.read()

# Fix 1: "本系统" -> \u201c本系统\u201d (简称引用)
content = content.replace('以下简称"本系统"）', '以下简称\u201c本系统\u201d）')

# Fix 2: "会议前-会议中-会议后" 
content = content.replace('围绕"会议前-会议中-会议后"的全流程', '围绕\u201c会议前-会议中-会议后\u201d的全流程')

# Fix 3: "登录" button
content = content.replace('点击"登录"按钮', '点击\u201c登录\u201d按钮')

# Fix 4: "🎙️ 语音上传转写" module
content = content.replace('选中"🎙️ 语音上传转写"模块', '选中\u201c🎙️ 语音上传转写\u201d模块')

# Fix 5: "📝 大模型智能摘要" module
content = content.replace('点击导航栏中的"📝 大模型智能摘要"模块', '点击导航栏中的\u201c📝 大模型智能摘要\u201d模块')

# Fix 6: "重新生成" button
content = content.replace('点击"重新生成"按钮', '点击\u201c重新生成\u201d按钮')

# Fix 7: "确认并一键同步到待办任务" button
content = content.replace('点击"确认并一键同步到待办任务"按钮', '点击\u201c确认并一键同步到待办任务\u201d按钮')

# Fix 8: "📋 待办任务分发" module
content = content.replace('集中在"📋 待办任务分发"模块', '集中在\u201c📋 待办任务分发\u201d模块')

# Fix 9: "手动添加待办任务" button
content = content.replace('点击"手动添加待办任务"按钮', '点击\u201c手动添加待办任务\u201d按钮')

# Fix 10: "一键同步至企业钉钉/飞书待办" button
content = content.replace('点击"一键同步至企业钉钉/飞书待办"按钮', '点击\u201c一键同步至企业钉钉/飞书待办\u201d按钮')

# Fix 11: "📂 历史会议记录" module
content = content.replace('点击导航栏中的"📂 历史会议记录"模块', '点击导航栏中的\u201c📂 历史会议记录\u201d模块')

# Fix 12: "⚙️ 系统参数设置" module
content = content.replace('导航栏中的"⚙️ 系统参数设置"模块', '导航栏中的\u201c⚙️ 系统参数设置\u201d模块')

# Fix 13: "忘记密码" link
content = content.replace('点击"忘记密码"链接', '点击\u201c忘记密码\u201d链接')

# Fix 14: "查看"、"导出"、"删除" (the complex one with multiple quotes)
content = content.replace('提供"查看"、"导出"、"删除"操作按钮。点击"查看"可跳转至该次会议的完整纪要详情页；点击"导出"可下载Word或PDF格式的会议纪要文档；点击"删除"可移除不需要的会议记录。"',
                           '提供\u201c查看\u201d、\u201c导出\u201d、\u201c删除\u201d操作按钮。点击\u201c查看\u201d可跳转至该次会议的完整纪要详情页；点击\u201c导出\u201d可下载Word或PDF格式的会议纪要文档；点击\u201c删除\u201d可移除不需要的会议记录。"')

# Fix 15: "正在转写中"、"已完成"、"转写失败" etc
content = content.replace('如"正在转写中"、"已完成"、"转写失败"等',
                           '如\u201c正在转写中\u201d、\u201c已完成\u201d、\u201c转写失败\u201d等')

# Fix 16: "研发团队详细会议纪要"、"市场部日常周会"
content = content.replace('如"研发团队详细会议纪要"、"市场部日常周会"等',
                           '如\u201c研发团队详细会议纪要\u201d、\u201c市场部日常周会\u201d等')

with open("generate_docx.py", "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed all Chinese quotation mark issues.")
