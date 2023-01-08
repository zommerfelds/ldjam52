import Gui.Text;

class LevelSelectView extends GameState {
	override function init() {
		final centeringFlow = new h2d.Flow(this);
		centeringFlow.backgroundTile = h2d.Tile.fromColor(0x082036);
		centeringFlow.fillWidth = true;
		centeringFlow.fillHeight = true;
		centeringFlow.horizontalAlign = Middle;
		centeringFlow.verticalAlign = Middle;
		centeringFlow.maxWidth = width;
		centeringFlow.layout = Vertical;
		centeringFlow.verticalSpacing = Gui.scaleAsInt(50);

		new Gui.Text("Select level", centeringFlow);

		centeringFlow.addSpacing(Gui.scaleAsInt(100));

		var totalTime = 0.0;
		var i = 0;
		for (level in App.ldtkProject.levels) {
			final iCopy = i;
			final locked = i > App.save.unlockedLevel;
			var label = level.identifier;
			if (App.save.levelRecords.get(i) != null) {
				label += ' (${MyUtils.formatTime(App.save.levelRecords.get(i))})';
				totalTime += App.save.levelRecords.get(i);
			}
			final button = new Gui.TextButton(centeringFlow, label, () -> {
				App.instance.switchState(new PlayView(iCopy));
			}, Gui.Colors.BLUE, 0.8);
			button.enabled = !locked;
			i++;
		}

		if (App.save.unlockedLevel >= App.ldtkProject.levels.length) {
			new Text("You beat all levels! Thank you for playing. :)<br/>Total best time: " + MyUtils.formatTime(totalTime),
				centeringFlow).textAlign = MultilineCenter;
		}
	}
}
