class App extends HerbalTeaApp {
	public static var instance:App;

	static function main() {
		instance = new App();
	}

	override function onload() {
		// switchState(new MenuView());

		final params = new js.html.URLSearchParams(js.Browser.window.location.search);
		final view = switch (params.get("start")) {
			case "play":
				// final levelIndex = params.get("level") == null ? 0 : Std.parseInt(params.get("level")) - 1;
				new PlayView();
			case "menu" | null:
				new MenuView();
			case x: throw 'invavid "start" query param "$x"';
		}

		switchState(view);
	}

	// TODO: move this to HerbalTeaApp
	public static function loadHighScore():Int {
		return hxd.Save.load({highscore: 0}).highscore;
	}

	public static function writeHighScore(highscore:Int) {
		hxd.Save.save({highscore: highscore});
	}
}
