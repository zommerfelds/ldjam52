class App extends HerbalTeaApp {
	public static var instance:App;
	public static final ldtkProject = new LdtkProject();

	static function main() {
		instance = new App();
	}

	public static final save = hxd.Save.load({unlockedLevel: 0});

	override function onload() {
		final params = new js.html.URLSearchParams(js.Browser.window.location.search);
		final view = switch (params.get("start")) {
			case "play":
				final levelIndex = params.get("level") == null ? 0 : Std.parseInt(params.get("level")) - 1;
				new PlayView(levelIndex);
			case "select":
				new LevelSelectView();
			case "end":
				new GameEndView();
			case "menu" | null:
				new MenuView();
			case x: throw 'invavid "start" query param "$x"';
		}

		switchState(view);
	}
}
