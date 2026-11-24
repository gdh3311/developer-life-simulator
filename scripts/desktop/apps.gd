extends RefCounted
## App registry: builds the content control for each in-game application.

const SCRIPTS := {
	"lab": preload("res://scripts/apps/request_lab_app.gd"),
	"ide": preload("res://scripts/desktop/ide_app.gd"),
	"terminal": preload("res://scripts/desktop/terminal_app.gd"),
	"codehub": preload("res://scripts/apps/codehub_app.gd"),
	"chat": preload("res://scripts/apps/chat_app.gd"),
	"tasks": preload("res://scripts/apps/tasks_app.gd"),
	"wiki": preload("res://scripts/apps/wiki_app.gd"),
	"monitor": preload("res://scripts/apps/monitor_app.gd"),
	"ai": preload("res://scripts/apps/ai_app.gd"),
	"browser": preload("res://scripts/apps/browser_app.gd"),
	"dashboard": preload("res://scripts/apps/dashboard_app.gd"),
	"docs": preload("res://scripts/apps/docs_app.gd"),
	"pork": preload("res://scripts/apps/pork_app.gd"),
}


static func build(id: String, desktop: Control) -> Control:
	var app: Control = SCRIPTS[id].new()
	if "desktop" in app:
		app.set("desktop", desktop)
	return app
