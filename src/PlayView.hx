import h2d.Bitmap;
import h2d.Object;
import hxd.Key;
import hxd.Res;

using ObjExt;

class PlayView extends GameState {
	var player:Object;
	override function init() {
		App.instance.engine.backgroundColor = 0x809F66;
		scale(2);

		addEventListener(onEvent);

		final level1 = new Bitmap(Res.level1.toTile(), this);
		level1.scale(6);
		final playerTile = Res.combine.toTile();
		playerTile.setCenterRatio();
		player = new Bitmap(playerTile, this);
		player.x = width / 2 / scaleX;
		player.y = height / 2 / scaleY;
	}

	function onEvent(event:hxd.Event) {}

	override function update(dt:Float) {
		if (Key.isDown(Key.LEFT)) {
			player.rotation -= dt * 1.0;
		}
		if (Key.isDown(Key.RIGHT)) {
			player.rotation += dt * 1.0;
		}
		if (Key.isDown(Key.UP)) {
			final vel = Utils.direction(player.rotation).multiply(dt * 40.0);
			trace('r: ${player.rotation} dir: ${Utils.direction(player.rotation)}');
			player.setPos(Utils.point(player).add(vel));
		}
	}
}
