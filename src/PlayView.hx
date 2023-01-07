import Utils.Point2d;
import h2d.Bitmap;
import h2d.Object;
import h2d.SpriteBatch;
import h2d.Tile;
import h2d.col.Point;
import h2d.col.Polygon;
import haxe.ds.HashMap;
import hxd.Key;
import hxd.Res;
import hxd.Save;
import hxd.res.Image;

using ObjExt;

class PlayView extends GameState {
	var player:Object;
	var cutter:Object;
	final levelData:LdtkProject.LdtkProject_Level;
	final levelIndex:Int;

	static final FIELD_TILE_SIZE = 6;

	final fieldElements = new HashMap<Point2d, BatchElement>();
	final fieldTileFull = Res.field_tiles.toTile()
		.sub(0 * FIELD_TILE_SIZE, 0, FIELD_TILE_SIZE, FIELD_TILE_SIZE, FIELD_TILE_SIZE * -0.5, FIELD_TILE_SIZE * -0.5);
	final fieldTileEmpty = Res.field_tiles.toTile()
		.sub(1 * FIELD_TILE_SIZE, 0, FIELD_TILE_SIZE, FIELD_TILE_SIZE, FIELD_TILE_SIZE * -0.5, FIELD_TILE_SIZE * -0.5);

	public function new(levelIndex) {
		super();
		this.levelIndex = levelIndex;

		levelData = App.ldtkProject.levels[levelIndex];
	}

	override function init() {
		App.instance.engine.backgroundColor = 0x809F66;
		scale(2);

		addEventListener(onEvent);

		final pixels = Res.loader.loadCache(levelData.bgImageInfos.relFilePath, Image).getPixels();
		final field = new SpriteBatch(Res.field_tiles.toTile(), this);
		for (x in 0...pixels.height) {
			for (y in 0...pixels.width) {
				final isField = pixels.getPixel(x, y) & 0xFFFFFF == 0;
				if (isField) {
					final element = new BatchElement(fieldTileFull);
					element.x = x * FIELD_TILE_SIZE;
					element.y = y * FIELD_TILE_SIZE;
					field.add(element);
					fieldElements.set(new Point2d(x, y), element);
				}
			}
		}

		final combine0 = levelData.l_Entities.all_Combine[0];

		final playerTile = Res.combine.toTile();
		playerTile.setCenterRatio(0.8, 0.5);
		player = new Bitmap(playerTile, this);
		player.x = combine0.pixelX;
		player.y = combine0.pixelY;

		// A bit of a hacky way to set the collision shape that cuts the crops.
		final cutterOffset = new Object(player);
		cutterOffset.x = 0;
		final cutterTile = Tile.fromColor(0x000000, 10, 60);
		cutterTile.setCenterRatio();
		cutter = new Bitmap(cutterTile, cutterOffset);
		cutter.visible = false;
	}

	function onEvent(event:hxd.Event) {}

	override function update(dt:Float) {
		if (Key.isDown(Key.UP)) {
			if (Key.isDown(Key.LEFT)) {
				player.rotation -= dt * 1.0;
			}
			if (Key.isDown(Key.RIGHT)) {
				player.rotation += dt * 1.0;
			}

			final vel = Utils.direction(player.rotation).multiply(dt * 50.0);
			player.setPos(Utils.point(player).add(vel));

			final bounds = cutter.getBounds(this);
			final xMin = Math.floor(bounds.xMin / FIELD_TILE_SIZE);
			final xMax = Math.ceil(bounds.xMax / FIELD_TILE_SIZE);
			final yMin = Math.floor(bounds.yMin / FIELD_TILE_SIZE);
			final yMax = Math.ceil(bounds.yMax / FIELD_TILE_SIZE);

			final localBounds = cutter.getBounds(cutter);
			final p = new Polygon([
				globalToLocal(cutter.localToGlobal(new Point(localBounds.xMin, localBounds.yMin))),
				globalToLocal(cutter.localToGlobal(new Point(localBounds.xMax, localBounds.yMin))),
				globalToLocal(cutter.localToGlobal(new Point(localBounds.xMax, localBounds.yMax))),
				globalToLocal(cutter.localToGlobal(new Point(localBounds.xMin, localBounds.yMax)))
			]);
			final collider = p.getCollider();

			for (y in yMin...yMax + 1) {
				for (x in xMin...xMax + 1) {
					final element = fieldElements.get(new Point2d(x, y));
					if (element != null && collider.contains(new Point(x * FIELD_TILE_SIZE, y * FIELD_TILE_SIZE))) {
						element.t = fieldTileEmpty;
						fieldElements.remove(new Point2d(x, y));
					}
				}
			}
		}
		if (!fieldElements.keys().hasNext()) {
			if (App.save.unlockedLevel < levelIndex + 1) {
				App.save.unlockedLevel = levelIndex + 1;
				Save.save(App.save);
			}

			if (levelIndex + 1 < App.ldtkProject.levels.length) {
				App.instance.switchState(new PlayView(levelIndex + 1));
			} else {
				App.instance.switchState(new GameEndView());
			}
		}
	}
}
