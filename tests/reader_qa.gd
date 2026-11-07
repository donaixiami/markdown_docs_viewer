@tool
extends EditorPlugin
const Parser := preload("res://addons/markdown_docs_viewer/md_parser.gd")
const Renderer := preload("res://addons/markdown_docs_viewer/md_renderer.gd")
const Style := preload("res://addons/markdown_docs_viewer/md_style.gd")
const Math := preload("res://addons/markdown_docs_viewer/md_math.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func _enter_tree() -> void:
	run.call_deferred()

func run() -> void:
	var style := Style.new()
	var path := OS.get_environment("MD_QA_IMAGE")
	if path.is_empty():
		var sample := Image.create(640, 400, false, Image.FORMAT_RGB8)
		sample.fill(Color.CORNFLOWER_BLUE)
		sample.save_jpg("user://external-test.jpg")
		path = ProjectSettings.globalize_path("user://external-test.jpg")
	var blocks := Parser.parse("before\n![](" + path + ")\nafter")
	check(blocks.size() == 3 and blocks[1].type == "image", "standalone image interrupts paragraph")
	check(blocks[1].path == path and blocks[1].alt == "", "Windows path and empty alt survive parsing")
	var titled := Parser.parse('![说明](<images/a (1).png> "图片标题")')[0]
	check(titled.path == "images/a (1).png" and titled.title == "图片标题", "spaces parentheses and title")
	check(Renderer.resolve_image_path("../assets/a%20b.png", "res://docs/test.md") == "res://assets/a b.png", "relative image path resolves against document")
	check(Renderer.resolve_image_path("file:///C:/Pictures/a%20b.png", "") == "C:/Pictures/a b.png", "file URI")
	check(Parser.parse("```md\n[TOC]\n![](a.png)\n$$x$$\n```")[0].type == "code", "code fences protect literal syntax")
	check(Parser.parse("$$x^2$$")[0].text == "x^2", "single line math")
	check(Parser.parse("$$\nx^2\n$$")[0].text == "x^2", "multiline math")
	check(Parser.parse("$$\nunclosed\n# Heading").back().type == "heading", "unclosed math preserves later headings")
	var yaml := Parser.parse("\ufeff---\r\ntitle: Demo\r\n---\r\n# Heading")
	check(yaml.size() == 2 and yaml[0].type == "frontmatter" and yaml[0].text == "title: Demo", "BOM CRLF YAML front matter")
	check(Parser.parse("---\n\n---")[0].type == "frontmatter", "empty YAML block")
	check(Parser.parse("text\n\n---").back().type == "hr", "body separator remains horizontal rule")
	check(Parser.parse("---\nunclosed\n# Heading").back().type == "heading", "unclosed YAML does not swallow headings")
	check(Parser.parse("> ---\n> title: text\n> ---")[0].blocks[0].type == "hr", "quote separator is not front matter")
	var definitions := Parser.parse("[^a]: first\n    continued\n[^]:\n[site]: https://example.com\n[]:")
	check(definitions.size() == 4 and definitions[0].text == "first\ncontinued", "separate definitions and indented continuation")
	check(definitions[1].id == "" and definitions[1].footnote, "empty footnote placeholder preserved")
	check(definitions[3].id == "" and not definitions[3].footnote, "empty reference placeholder preserved")
	var renderer := Renderer.new(style, "res://docs/example.md")
	var picture := renderer._image(blocks[1])
	check(picture is TextureRect and picture.texture != null, "actual reported external JPEG decodes")
	picture.free()
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.CORNFLOWER_BLUE)
	img.save_png("res://docs/图片 (test).png")
	var relative := renderer._image({"path":"图片 (test).png", "alt":"", "title":""})
	check(relative is TextureRect, "relative non-imported Unicode image loads")
	relative.free()
	var missing := renderer._image({"path":"absent.png", "alt":"Missing", "title":""})
	check(missing is RichTextLabel and missing.text.contains("Image not found"), "missing image has explicit fallback")
	missing.free()
	for formula in ["a's'd'fa's'd'f'sa'd'f", "E=mc^2", "x_i^{n+1}", "\\frac{1}{\\sqrt{x^2+1}}", "\\alpha+\\beta\\leq\\pi", "\\sum_{i=1}^{n}i", "\\text{speed}=\\frac{d}{t}"]:
		var math := Math.new()
		math.configure(formula, style.font, style.font_italic, 22, style.text)
		check(math.error.is_empty() and math.custom_minimum_size.x > 24, "math: " + formula)
		math.free()
	var unsupported := Math.new()
	unsupported.configure("\\begin{matrix}1\\end{matrix}", style.font, style.font_italic, 22, style.text)
	check(not unsupported.error.is_empty(), "unsupported TeX reported")
	unsupported.free()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 1750)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = style.bg
	bg.size = viewport.size
	viewport.add_child(bg)
	var source := "---\n\n---\n\n# 阅读效果检查\n\n[TOC]\n\n## 本地图片\n\n![](" + path + ")\n\n## 空表格\n\n脚注[^注] 与 [Godot][site]\n\n[^注]: 说明内容\n[^]:\n[site]: https://godotengine.org/\n[]:\n\n| | | |\n|---|---|---|\n| | | |\n| | | |\n| | | |\n\n## 公式\n\n$$a's'd'fa's'd'f'sa'd'f$$\n\n$$\\frac{1}{\\sqrt{x^2+1}} + E=mc^2$$\n\n## 公式\n\n| 参数 | 类型 | 说明 |\n|---|:---:|---:|\n| `speed` | float | 移动速度 |\n| `acceleration` | float | 加速度 |"
	var doc := renderer.build(Parser.parse(source))
	doc.position = Vector2(180, 20)
	doc.size.x = 740
	viewport.add_child(doc)
	for n in 10: await get_tree().process_frame
	check(renderer.anchors.has("footnote-注"), "footnote definition anchor")
	var note_label := renderer.rich(renderer._inline("正文[^注]"))
	check(not note_label.get_parsed_text().contains("[font_size="), "footnote BBCode supported by Godot")
	note_label.free()
	check(renderer._inline("正文[^注]").contains("[font_size="), "footnote marker rendered as compact link")
	check(renderer._inline("[Godot][site]").contains("url=https://godotengine.org/"), "reference link resolves")
	check(not renderer._inline("`[^注]` `[Godot][site]`").contains("[url="), "code spans do not resolve references")
	check(renderer._inline("[Missing][unknown]").contains("Missing"), "unknown reference remains visible")
	check(renderer.anchors.has("公式-1"), "duplicate heading anchors")
	check(renderer._toc_nodes[0].get_child_count() == 5, "TOC includes later headings")
	var clicked := []
	renderer.link_clicked.connect(func(target): clicked.append(target))
	var last_link: RichTextLabel = renderer._toc_nodes[0].get_child(4).get_child(0)
	last_link.meta_clicked.emit("#公式-1")
	check(clicked == ["#公式-1"], "TOC forwards heading jump")
	for child in doc.get_children():
		if child is TextureRect:
			check(child.size.y > 100 and child.size.x <= 740, "image has proportional visible height")
		if child is ScrollContainer and child.get_child(0) is PanelContainer:
			check(child.get_child(0).size.x >= 730, "table fills document width")
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png("res://reader-preview.png")
	doc.size.x = 360
	for n in 10: await get_tree().process_frame
	for child in doc.get_children():
		if child is TextureRect: check(child.size.y > 0 and child.size.x <= 360, "image resizes in narrow document")
	# Verify the panel's anchor navigation, not only the renderer signal.
	var file := FileAccess.open("res://navigation.md", FileAccess.WRITE)
	file.store_string("[TOC]\n\n# Start\n\n" + "Paragraph.\n\n".repeat(50) + "## Destination\n\nEnd")
	file.close()
	var panel = load("res://addons/markdown_docs_viewer/md_panel.gd").new()
	panel.size = Vector2(1000, 700)
	viewport.add_child(panel)
	panel.open("res://navigation.md")
	for n in 10: await get_tree().process_frame
	panel._on_link("#destination")
	for n in 5: await get_tree().process_frame
	check(panel._scroll.scroll_vertical > 0, "panel scrolls to TOC destination")
	panel.queue_free()
	print("Reader checks: ", checks, "; failures: ", failures)
	get_tree().quit(1 if failures else 0)
