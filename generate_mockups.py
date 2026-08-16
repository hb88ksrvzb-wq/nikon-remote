import os
from PIL import Image, ImageDraw, ImageFont

def get_chinese_font(size=14, bold=False):
    # Try common font paths on Windows
    font_paths = [
        "C:\\Windows\\Fonts\\msyh.ttc",  # Microsoft YaHei
        "C:\\Windows\\Fonts\\msyhl.ttc", # Microsoft YaHei Light
        "C:\\Windows\\Fonts\\simsun.ttc",  # SimSun
        "C:\\Windows\\Fonts\\simsun.ttf",
        "C:\\Windows\\Fonts\\msyhbd.ttc", # Microsoft YaHei Bold
    ]
    # If bold is requested, try to use a bold font path
    if bold:
        font_paths.insert(0, "C:\\Windows\\Fonts\\msyhbd.ttc")
    
    for path in font_paths:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except:
                pass
    return ImageFont.load_default()

def draw_wrapped_text(draw, text, x, y, max_width, font, fill, line_spacing=4):
    """Draws text wrapped within max_width at (x, y) and returns the ending y position."""
    words = list(text)
    lines = []
    current_line = ""
    for char in words:
        test_line = current_line + char
        try:
            bbox = font.getbbox(test_line)
            width = bbox[2] - bbox[0]
        except AttributeError:
            width, _ = font.getsize(test_line)
            
        if width <= max_width:
            current_line = test_line
        else:
            if current_line:
                lines.append(current_line)
            current_line = char
    if current_line:
        lines.append(current_line)
        
    current_y = y
    for line in lines:
        draw.text((x, current_y), line, font=font, fill=fill)
        try:
            bbox = font.getbbox(line)
            height = bbox[3] - bbox[1]
        except AttributeError:
            _, height = font.getsize(line)
        current_y += height + line_spacing
    return current_y

def draw_window_chrome(draw, width, height, title_text="基于大语言模型的智能会议纪要与任务分发系统 V1.0"):
    # Browser bar (light gray)
    draw.rectangle([0, 0, width, 40], fill="#e2e8f0")
    # Red, yellow, green window controls
    draw.ellipse([15, 14, 25, 24], fill="#ff5f56")
    draw.ellipse([31, 14, 41, 24], fill="#ffbd2e")
    draw.ellipse([47, 14, 57, 24], fill="#27c93f")
    # URL bar
    draw.rounded_rectangle([90, 8, width - 40, 32], radius=4, fill="#ffffff", outline="#cbd5e1", width=1)
    # URL text
    font_url = get_chinese_font(12)
    draw.text((100, 12), "https://meeting-assistant.ai/workspace", font=font_url, fill="#94a3b8")

def draw_sidebar(draw, height, active_index=0):
    # Sidebar bar background
    draw.rectangle([0, 40, 220, height], fill="#1e293b")
    # Logo / Title
    font_logo = get_chinese_font(16, bold=True)
    draw.text((20, 60), "智能会议助手 V1.0", font=font_logo, fill="#38bdf8")
    
    # Separator
    draw.line([20, 90, 200, 90], fill="#334155", width=1)
    
    items = [
        ("🎙️  语音上传转写", 0),
        ("📝  大模型智能摘要", 1),
        ("📋  待办任务分发", 2),
        ("📂  历史会议记录", 3),
        ("⚙️  系统参数设置", 4)
    ]
    
    font_item = get_chinese_font(14)
    for i, (text, idx) in enumerate(items):
        y_pos = 110 + i * 45
        if idx == active_index:
            # Active state
            draw.rounded_rectangle([10, y_pos, 210, y_pos + 36], radius=6, fill="#0f172a")
            draw.text((25, y_pos + 8), text, font=font_item, fill="#38bdf8")
        else:
            draw.text((25, y_pos + 8), text, font=font_item, fill="#94a3b8")
            
    # Bottom user profile
    draw.line([20, height - 60, 200, height - 60], fill="#334155", width=1)
    draw.text((25, height - 45), "👤  管理员 (Admin)", font=font_item, fill="#cbd5e1")

# Create image output directory
os.makedirs("img", exist_ok=True)

# ==================== IMAGE 1: LOGIN PAGE ====================
print("Generating login_page.png...")
img1 = Image.new("RGB", (900, 600), "#f1f5f9")
draw1 = ImageDraw.Draw(img1)
draw_window_chrome(draw1, 900, 600)

# Login card in center
card_x1, card_y1, card_x2, card_y2 = 260, 130, 640, 490
draw1.rounded_rectangle([card_x1, card_y1, card_x2, card_y2], radius=12, fill="#ffffff", outline="#e2e8f0", width=2)

# Card shadow effect (simple)
draw1.rounded_rectangle([card_x1+2, card_y1+2, card_x2+2, card_y2+2], radius=12, outline="#cbd5e1", width=1)

# Title & Subtitle inside card
font_title = get_chinese_font(22, bold=True)
font_subtitle = get_chinese_font(11)
draw1.text((310, 160), "会议智能助手登录", font=font_title, fill="#0f172a")

# Centered wrapping for subtitle
subtitle_text = "基于大语言模型的智能会议纪要与任务分发系统"
draw_wrapped_text(draw1, subtitle_text, 285, 200, 350, font_subtitle, fill="#64748b")

# Input Username
font_label = get_chinese_font(14, bold=True)
font_placeholder = get_chinese_font(12)
draw1.text((300, 235), "用户名 / 邮箱", font=font_label, fill="#334155")
draw1.rounded_rectangle([300, 255, 600, 295], radius=6, fill="#ffffff", outline="#cbd5e1", width=1)
draw1.text((315, 265), "admin@company.com", font=font_placeholder, fill="#0f172a")

# Input Password
draw1.text((300, 310), "密码", font=font_label, fill="#334155")
draw1.rounded_rectangle([300, 330, 600, 370], radius=6, fill="#ffffff", outline="#cbd5e1", width=1)
draw1.text((315, 340), "••••••••••••••••", font=font_placeholder, fill="#475569")

# Login Button
draw1.rounded_rectangle([300, 400, 600, 440], radius=6, fill="#0284c7")
font_btn = get_chinese_font(15, bold=True)
draw1.text((430, 410), "登  录", font=font_btn, fill="#ffffff")

# Copyright text on bottom
font_copy = get_chinese_font(11)
draw1.text((350, 540), "© 2026 北京科技创新有限公司. 版权所有", font=font_copy, fill="#94a3b8")
img1.save("img/login_page.png")


# ==================== IMAGE 2: AUDIO UPLOAD ====================
print("Generating dashboard_upload.png...")
img2 = Image.new("RGB", (900, 600), "#f8fafc")
draw2 = ImageDraw.Draw(img2)
draw_window_chrome(draw2, 900, 600)
draw_sidebar(draw2, 600, active_index=0)

# Content Title
font_ct = get_chinese_font(18, bold=True)
draw2.text((245, 60), "会议音频上传与实时语音转写", font=font_ct, fill="#0f172a")

# Upload Area Card (Left Side)
draw2.rounded_rectangle([245, 100, 545, 320], radius=8, fill="#ffffff", outline="#e2e8f0", width=1)
# Dashed-like line for upload (represented by smaller rects or standard border)
draw2.rounded_rectangle([260, 115, 530, 305], radius=6, outline="#cbd5e1", width=1) # simplified outline

# Upload Icon & text
font_up_title = get_chinese_font(15, bold=True)
font_up_sub = get_chinese_font(12)
draw2.text((310, 170), "📥 拖拽会议音频文件到此处", font=font_up_title, fill="#0284c7")
draw2.text((315, 205), "或者 点击选择本地文件上传", font=font_up_sub, fill="#64748b")
draw2.text((275, 235), "支持格式：mp3, wav, m4a | 大小不超过500MB", font=font_up_sub, fill="#94a3b8")

# Uploading Progress Card (Left Side Bottom)
draw2.rounded_rectangle([245, 335, 545, 560], radius=8, fill="#ffffff", outline="#e2e8f0", width=1)
draw2.text((260, 350), "正在转写中的任务 (1)", font=get_chinese_font(13, bold=True), fill="#334155")

# File row - truncated to prevent overflow
draw2.rounded_rectangle([260, 380, 530, 440], radius=6, fill="#f1f5f9", outline="#e2e8f0", width=1)
draw2.text((275, 395), "🎙️ 研发一期进度对齐会议...mp3", font=get_chinese_font(12, bold=True), fill="#0f172a")
# Progress bar background
draw2.rounded_rectangle([275, 418, 450, 426], radius=4, fill="#cbd5e1")
# Progress bar active (80%)
draw2.rounded_rectangle([275, 418, 415, 426], radius=4, fill="#10b981")
draw2.text((460, 413), "80% (ASR)", font=get_chinese_font(11), fill="#10b981")

# Speaker options
draw2.text((260, 460), "音频转写核心配置：", font=get_chinese_font(12, bold=True), fill="#475569")
draw2.text((260, 485), "• 说话人识别：开启 (2-5人)", font=get_chinese_font(12), fill="#64748b")
draw2.text((260, 508), "• ASR识别引擎：高精双工混响引擎 V2", font=get_chinese_font(12), fill="#64748b")
draw2.text((260, 531), "• 热词字典加载：互联网技术热词、软件开发", font=get_chinese_font(12), fill="#64748b")

# Live Transcript Card (Right Side)
draw2.rounded_rectangle([560, 100, 880, 560], radius=8, fill="#ffffff", outline="#e2e8f0", width=1)
draw2.text((575, 115), "实时语音转写文本预览", font=get_chinese_font(13, bold=True), fill="#334155")
draw2.line([575, 140, 865, 140], fill="#e2e8f0", width=1)

transcripts = [
    ("[00:01] 说话人1", "大家早上好！今天召集大家开会，主要是对齐我们“智能会议助手 V1.0”一期项目的开发进度和关键节点。"),
    ("[00:45] 说话人2", "好的，张总。目前我负责的前端UI原型设计以及路由基础搭建工作已经基本完成了，随时可以开始配合写业务。"),
    ("[01:20] 说话人3", "后端这边的进度也在预期内。核心的音频上传、ASR对接以及配合LLM做摘要、待办提取的接口都已经基本调通了。"),
    ("[02:05] 说话人1", "很好，进度超出预期。那我们需要在下周一（6月8日）完成前后端联调，并让测试介入，大家没问题吧？"),
    ("[02:45] 说话人2", "没问题，我这周内会把主要页面的静态效果做完。"),
    ("[03:10] 说话人3", "后端也可以按时交付接口，下周一可以准时启动联调。")
]

y_txt = 155
for speaker, text in transcripts:
    draw2.text((575, y_txt), speaker, font=get_chinese_font(11, bold=True), fill="#0284c7")
    # Auto word wrap for transcript block using robust draw_wrapped_text
    font_body = get_chinese_font(11)
    y_txt = draw_wrapped_text(draw2, text, 575, y_txt + 16, 290, font_body, "#334155", line_spacing=3)
    y_txt += 10 # paragraph separation

img2.save("img/dashboard_upload.png")


# ==================== IMAGE 3: AI SUMMARY ====================
print("Generating ai_summary.png...")
img3 = Image.new("RGB", (900, 600), "#f8fafc")
draw3 = ImageDraw.Draw(img3)
draw_window_chrome(draw3, 900, 600)
draw_sidebar(draw3, 600, active_index=1)

# Content Title
draw3.text((245, 60), "大模型智能会议纪要与摘要提炼", font=font_ct, fill="#0f172a")

# Configuration Bar
draw3.rounded_rectangle([245, 95, 880, 140], radius=6, fill="#f1f5f9", outline="#e2e8f0", width=1)
draw3.text((260, 110), "当前模型：GPT-4o (精调版)", font=get_chinese_font(12, bold=True), fill="#334155")
draw3.text((450, 110), "提示词模板：研发团队详细会议纪要", font=get_chinese_font(12, bold=True), fill="#334155")
draw3.rounded_rectangle([760, 103, 865, 132], radius=4, fill="#0284c7")
draw3.text((775, 110), "🪄 重新生成", font=get_chinese_font(12, bold=True), fill="#ffffff")

# Summary columns: Left side ASR source, Right side AI output
# Left source
draw3.rounded_rectangle([245, 155, 495, 560], radius=8, fill="#ffffff", outline="#e2e8f0", width=1)
draw3.text((260, 170), "转写文本摘要输入源 (ASR)", font=get_chinese_font(13, bold=True), fill="#334155")
draw3.line([260, 195, 480, 195], fill="#e2e8f0", width=1)

src_text = """一期项目研发计划对齐会...
张总：各位早上好。今天主要是对齐智能会议助手V1.0的研发进度。
李娜（前端）：我已经完成了前端UI原型和核心路由搭建，这周能把静态页写完。
王强（后端）：后端API与ASR、大模型接口基本调通，周五能提供初始联调接口。
张总：很好。目标是下周一（6月8日）进入联调，并开始系统集成测试。
李娜、王强：可以，按计划进行。
张总：另外，下周末前必须输出完整的软著申请材料。"""

font_src = get_chinese_font(11)
y_src = 205
for line in src_text.split("\n"):
    if line.strip():
        # Wrap source text to prevent overflowing x=495 boundary (max width ~215px)
        y_src = draw_wrapped_text(draw3, line, 260, y_src, 215, font_src, "#475569", line_spacing=3)
        y_src += 5

# Right Output
draw3.rounded_rectangle([510, 155, 880, 560], radius=8, fill="#ffffff", outline="#e2e8f0", width=1)
draw3.text((525, 170), "✨ 智能生成的会议纪要", font=get_chinese_font(13, bold=True), fill="#0284c7")
draw3.line([525, 195, 865, 195], fill="#e2e8f0", width=1)

# Summary layout elements - redesigned to wrap beautifully
summary_nodes = [
    ("【会议名称】", "基于LLM的智能会议系统V1.0项目进度对齐会", "#0f172a"),
    ("【会议时间】", "2026年6月3日 10:00 - 10:30", "#334155"),
    ("【主要议程与关键讨论】", "", "#0284c7"),
    (" 1. 前端进度: ", "李娜完成核心路由与UI原型，本周内输出全部静态页面。", "#475569"),
    (" 2. 后端进度: ", "王强完成ASR、大语言模型核心接口开发，本周五提供接口。", "#475569"),
    (" 3. 总体规划: ", "张总确定下周一启动前后端联调，开始集成测试。", "#475569"),
    ("【核心结论及决议】", "", "#10b981"),
    (" • 联调时间节点: ", "定于2026年6月8日，全体研发参与联调。", "#0f172a"),
    (" • 软著申报任务: ", "下周末前输出系统的软件著作权申报材料与手册。", "#0f172a")
]

y_sum = 205
for heading, body, color in summary_nodes:
    if not body:
        # Full Section Heading
        y_sum = draw_wrapped_text(draw3, heading, 525, y_sum, 335, get_chinese_font(12, bold=True), color, line_spacing=3)
        y_sum += 6
    else:
        # Combined Bullet / Item wrapping safely within 335px limit
        full_text = heading + body
        is_bullet = heading.strip().startswith("•") or heading.strip().startswith("1.") or heading.strip().startswith("2.") or heading.strip().startswith("3.")
        x_pos = 535 if is_bullet else 525
        max_w = 325 if is_bullet else 335
        
        y_sum = draw_wrapped_text(draw3, full_text, x_pos, y_sum, max_w, get_chinese_font(11), "#334155", line_spacing=3)
        y_sum += 4

# Sync / Action button
draw3.rounded_rectangle([525, 510, 865, 545], radius=6, fill="#10b981")
draw3.text((615, 520), "👉 确认并一键同步到待办任务列表", font=get_chinese_font(13, bold=True), fill="#ffffff")

img3.save("img/ai_summary.png")


# ==================== IMAGE 4: TASK DISTRIBUTION ====================
print("Generating task_distribution.png...")
img4 = Image.new("RGB", (900, 600), "#f8fafc")
draw4 = ImageDraw.Draw(img4)
draw_window_chrome(draw4, 900, 600)
draw_sidebar(draw4, 600, active_index=2)

# Content Title
draw4.text((245, 60), "待办事项提取与任务智能分发", font=font_ct, fill="#0f172a")

# Top prompt
draw4.rounded_rectangle([245, 95, 880, 135], radius=6, fill="#e0f2fe", outline="#bae6fd", width=1)
draw4.text((260, 108), "💡 AI 算法自动从本次会议提炼出 3 项待办事项，并已智能匹配负责人：", font=get_chinese_font(12, bold=True), fill="#0369a1")

# Task cards (3 horizontal list items)
tasks = [
    {"title": "任务一：完成前端UI与历史纪要面板静态页面重构", "owner": "李娜 (前端研发)", "prio": "紧急/高", "prio_color": "#ef4444", "date": "2026-06-07"},
    {"title": "任务二：联调大模型接口并测试Prompt分发稳定性", "owner": "王强 (后端研发)", "prio": "紧急/高", "prio_color": "#ef4444", "date": "2026-06-07"},
    {"title": "任务三：高并发音视频转写组件响应性能调优", "owner": "陈刚 (架构师)", "prio": "普通/中", "prio_color": "#f59e0b", "date": "2026-06-12"}
]

y_task = 150
for i, t in enumerate(tasks):
    # Border card
    draw4.rounded_rectangle([245, y_task, 880, y_task + 105], radius=8, fill="#ffffff", outline="#e2e8f0", width=1)
    
    # Checkbox placeholder
    draw4.rounded_rectangle([265, y_task + 40, 285, y_task + 60], radius=4, fill="#ffffff", outline="#0284c7", width=2)
    # Checkmark drawn simply
    draw4.line([269, y_task + 50, 274, y_task + 55], fill="#0284c7", width=2)
    draw4.line([274, y_task + 55, 281, y_task + 43], fill="#0284c7", width=2)
    
    # Task Title
    draw4.text((300, y_task + 15), t["title"], font=get_chinese_font(14, bold=True), fill="#0f172a")
    
    # Task metadata
    draw4.text((300, y_task + 45), f"👤 默认指派: {t['owner']}", font=get_chinese_font(12), fill="#475569")
    draw4.text((480, y_task + 45), f"📅 截止时间: {t['date']}", font=get_chinese_font(12), fill="#475569")
    
    # Priority badge
    draw4.text((660, y_task + 45), "优先级:", font=get_chinese_font(12), fill="#475569")
    draw4.rounded_rectangle([710, y_task + 41, 765, y_task + 61], radius=4, fill=t["prio_color"])
    draw4.text((718, y_task + 44), t["prio"], font=get_chinese_font(11, bold=True), fill="#ffffff")
    
    # Action button
    draw4.rounded_rectangle([790, y_task + 35, 865, y_task + 70], radius=4, fill="#ffffff", outline="#cbd5e1", width=1)
    draw4.text((804, y_task + 45), "配置修改", font=get_chinese_font(12), fill="#334155")
    
    y_task += 120

# Bottom action bar
draw4.rounded_rectangle([245, 510, 545, 555], radius=6, fill="#ffffff", outline="#0284c7", width=1)
draw4.text((350, 523), "＋ 手动添加待办任务", font=get_chinese_font(13, bold=True), fill="#0284c7")

draw4.rounded_rectangle([565, 510, 880, 555], radius=6, fill="#0284c7")
draw4.text((660, 523), "🚀 一键同步至企业钉钉/飞书待办", font=get_chinese_font(13, bold=True), fill="#ffffff")

img4.save("img/task_distribution.png")


# ==================== IMAGE 5: HISTORY RECORDS ====================
print("Generating history_records.png...")
img5 = Image.new("RGB", (900, 600), "#f8fafc")
draw5 = ImageDraw.Draw(img5)
draw_window_chrome(draw5, 900, 600)
draw_sidebar(draw5, 600, active_index=3)

# Content Title
draw5.text((245, 60), "历史会议纪要检索与管理中心", font=font_ct, fill="#0f172a")

# Search and filter header
draw5.rounded_rectangle([245, 100, 580, 140], radius=6, fill="#ffffff", outline="#cbd5e1", width=1)
draw5.text((260, 112), "🔍 输入会议名称、议程、关键词进行智能检索...", font=get_chinese_font(12), fill="#94a3b8")

draw5.rounded_rectangle([595, 100, 725, 140], radius=6, fill="#ffffff", outline="#cbd5e1", width=1)
draw5.text((610, 112), "📅 全部会议日期 🔽", font=get_chinese_font(12), fill="#475569")

draw5.rounded_rectangle([740, 100, 880, 140], radius=6, fill="#0284c7")
draw5.text((780, 112), "🔍 检索", font=get_chinese_font(13, bold=True), fill="#ffffff")

# Table card
draw5.rounded_rectangle([245, 160, 880, 560], radius=8, fill="#ffffff", outline="#e2e8f0", width=1)

# Table Header - rearranged to prevent overlaps
headers = [
    ("会议主题", 255),
    ("召开时间", 510),
    ("时长", 640),
    ("提取待办", 700),
    ("操作", 800)
]
font_th = get_chinese_font(12, bold=True)
for h, x_pos in headers:
    draw5.text((x_pos, 175), h, font=font_th, fill="#334155")
draw5.line([260, 195, 865, 195], fill="#cbd5e1", width=1)

# Table Rows
rows = [
    ("🎙️ 智能会议助手V1.0一期进度对齐会", "2026-06-03 10:00", "30分钟", "3项已分发", "查看 | 导出 | 🔴 删除"),
    ("🎙️ ASR高精语音转写算法模型选型会", "2026-05-28 14:00", "75分钟", "2项已完成", "查看 | 导出 | 🔴 删除"),
    ("🎙️ 产品UI原型走查及交互细节评审会", "2026-05-20 09:30", "45分钟", "4项已完成", "查看 | 导出 | 🔴 删除"),
    ("🎙️ 提示词工程Prompt工程模板库评审", "2026-05-15 16:00", "50分钟", "1项进行中", "查看 | 导出 | 🔴 删除"),
    ("🎙️ 二季度重点研发工作部署与预算对齐", "2026-04-10 11:00", "90分钟", "无待办事项", "查看 | 导出 | 🔴 删除")
]

font_row = get_chinese_font(12)
y_row = 210
for r in rows:
    # Truncate meeting theme to prevent overlapping with time column (at x=510)
    theme_text = r[0]
    if len(theme_text) > 14:
        theme_text = theme_text[:13] + "..."
        
    draw5.text((255, y_row), theme_text, font=get_chinese_font(12, bold=True), fill="#0f172a")
    draw5.text((510, y_row), r[1], font=font_row, fill="#475569")
    draw5.text((640, y_row), r[2], font=font_row, fill="#475569")
    
    # Task status style
    status_color = "#10b981" if "已完成" in r[3] else ("#0284c7" if "已分发" in r[3] else "#64748b")
    draw5.text((700, y_row), r[3], font=get_chinese_font(12, bold=True), fill=status_color)
    
    # Actions style (highlights)
    draw5.text((800, y_row), r[4].split("|")[0], font=font_row, fill="#0284c7")
    draw5.text((828, y_row), "|", font=font_row, fill="#e2e8f0")
    draw5.text((838, y_row), r[4].split("|")[1], font=font_row, fill="#10b981")
    draw5.text((860, y_row), "🗑️", font=font_row, fill="#ef4444")
    
    # Bottom border
    draw5.line([260, y_row + 25, 865, y_row + 25], fill="#f1f5f9", width=1)
    y_row += 35

# Pagination
draw5.text((500, 520), "共 12 条记录 |  ⏪ 1  2  3 ⏩  | 10条/页", font=get_chinese_font(11), fill="#64748b")

img5.save("img/history_records.png")
print("All mockups generated successfully with automatic text wrapping and layout optimization!")
