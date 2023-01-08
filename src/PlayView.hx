import Gui.Text;
import Gui.TileButton;
import Utils.Point2d;
import h2d.Bitmap;
import h2d.Graphics;
import h2d.Interactive;
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

using Lambda;
using ObjExt;
using StringTools;

enum CombineInput {
	TurnLeft;
	TurnRight;
	Forward;
}

typedef Combine = {
	obj:Object,
	cutter:Object,
	startPos:Point,
	startRotation:Float,
	recordedInput:Array<Array<CombineInput>>
};

class PlayView extends GameState {
	final levelData:LdtkProject.LdtkProject_Level;
	final levelIndex:Int;

	final selectedHighlight = new Graphics();
	final combines:Array<Combine> = [];
	var activeCombine:Null<Combine> = null;
	var currentFrame = 0;
	var timeAcc = 0.0;

	var paused = true;
	var timeText:Text;

	static final FRAME_TIME = 1 / 60.0;
	static final FIELD_TILE_SIZE = 6;

	final fieldElements = new HashMap<Point2d, {e:BatchElement, fullTile:Tile, emptyTile:Tile}>();
	var completedFields = 0;
	var numFields = 0;
	final fieldTiles = Res.field_tiles.toTile().gridFlatten(FIELD_TILE_SIZE, FIELD_TILE_SIZE * -0.5, FIELD_TILE_SIZE * -0.5);
	final fieldTilesFull = [0, 1, 2];
	final fieldTilesEmpty = [3, 4, 5];

	public function new(levelIndex) {
		super();
		this.levelIndex = levelIndex;

		trace("foo", fieldTiles.length);

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
					final fullTile = fieldTiles[fieldTilesFull[Std.random(fieldTilesFull.length)]];
					final emptyTile = fieldTiles[fieldTilesEmpty[Std.random(fieldTilesEmpty.length)]];
					final element = new BatchElement(fullTile);
					element.x = x * FIELD_TILE_SIZE;
					element.y = y * FIELD_TILE_SIZE;
					field.add(element);
					fieldElements.set(new Point2d(x, y), {e: element, fullTile: fullTile, emptyTile: emptyTile});
					numFields++;
				}
			}
		}

		final combineTile = Res.combine.toTile();
		combineTile.setCenterRatio(0.8, 0.5);

		for (combineData in levelData.l_Entities.all_Combine) {
			final combineObj = new Bitmap(combineTile, this);
			combineObj.x = combineData.pixelX;
			combineObj.y = combineData.pixelY;

			// A bit of a hacky way to set the collision shape that cuts the crops.
			final cutterOffset = new Object(combineObj);
			cutterOffset.x = 0;
			final cutterTile = Tile.fromColor(0x000000, 10, 60);
			cutterTile.setCenterRatio();
			final cutter = new Bitmap(cutterTile, cutterOffset);
			cutter.visible = false;

			final combine:Combine = {
				obj: combineObj,
				cutter: cutter,
				startPos: Utils.point(combineObj),
				startRotation: combineObj.rotation,
				recordedInput: []
			};
			final interactive = new Interactive(combineTile.width, combineTile.height, combineObj);
			interactive.x += combineTile.dx;
			interactive.y += combineTile.dy;
			// interactive.backgroundColor = 0xffff0000;
			interactive.onClick = e -> {
				activeCombine = combine;
				// combine.recordedInput = [];
				selectedHighlight.visible = true;
				combine.obj.addChild(selectedHighlight);
				paused = true;
				// resetTime();
			};
			final select = new Graphics(combineObj);
			select.beginFill(0xffffffff, 0.3);
			select.drawCircle(-20, 0, combineTile.width * 0.6);
			new FuncObject(() -> {
				interactive.visible = (currentFrame == 0);
				select.visible = (activeCombine == null);
			}, combineObj);
			combines.push(combine);
		}

		selectedHighlight.lineStyle(2, 0xffffffff);
		selectedHighlight.drawCircle(-20, 0, combineTile.width * 0.6);

		final BUTTON_TILE_SIZE = 11;
		/*
			final buttonPlayTile = Res.buttons.toTile()
				.sub(0 * BUTTON_TILE_SIZE, 0, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE * -0.5, BUTTON_TILE_SIZE * -0.5);
			final buttonPlay = new TileButton(buttonPlayTile, this, () -> {
				paused = false;
			});
			buttonPlay.x = 800;
			buttonPlay.y = 400;
			final buttonPauseTile = Res.buttons.toTile()
				.sub(2 * BUTTON_TILE_SIZE, 0, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE * -0.5, BUTTON_TILE_SIZE * -0.5);
			final buttonPause = new TileButton(buttonPauseTile, this, () -> {
				paused = true;
			});
			buttonPause.x = buttonPlay.x;
			buttonPause.y = buttonPlay.y;
			new FuncObject(() -> {
				buttonPlay.visible = paused;
				buttonPause.visible = !paused;
			}, buttonPlay);
		 */
		final buttonBackTile = Res.buttons.toTile()
			.sub(1 * BUTTON_TILE_SIZE, 0, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE * -0.5, BUTTON_TILE_SIZE * -0.5);
		final buttonBack = new TileButton(buttonBackTile, this, () -> {
			activeCombine = null;
			selectedHighlight.visible = false;
			paused = true;
			resetTime();
		});
		buttonBack.x = 880;
		buttonBack.y = 400;

		timeText = new Text("", this, 0.5);
		timeText.textColor = 0x000000;
		timeText.dropShadow = {
			dx: 3,
			dy: 3,
			color: 0x000000,
			alpha: 0.5
		};
		timeText.x = 800;
		timeText.y = 480;
	}

	function resetTime() {
		currentFrame = 0;
		timeAcc = 0;
		completedFields = 0;
		for (e in fieldElements) {
			e.e.t = e.fullTile;
		}
		for (c in combines) {
			c.obj.setPos(c.startPos);
			c.obj.rotation = c.startRotation;
		}
	}

	function onEvent(event:hxd.Event) {}

	override function update(dt:Float) {
		final date = Date.fromTime(currentFrame * FRAME_TIME * 1000);
		timeText.text = DateTools.format(date, "%M:%S.") + ("" + Std.int(((currentFrame * FRAME_TIME) % 1.0) * 100)).lpad("0", 2);

		if (Key.isDown(Key.UP)) {
			paused = false;
		}
		if (paused)
			return;
		// if (activeCombine == null)
		//	return;

		timeAcc++;
		if (timeAcc >= FRAME_TIME) {
			timeAcc -= FRAME_TIME;
			currentFrame++;

			for (combine in combines) {
				var inputs = [];
				if (activeCombine == combine) {
					if (Key.isDown(Key.UP)) {
						inputs.push(Forward);
					}
					if (Key.isDown(Key.LEFT)) {
						inputs.push(TurnLeft);
					}
					if (Key.isDown(Key.RIGHT)) {
						inputs.push(TurnRight);
					}
					activeCombine.recordedInput.splice(currentFrame + 1, activeCombine.recordedInput.length);
					while (activeCombine.recordedInput.length < currentFrame) {
						activeCombine.recordedInput.push([]);
					}
					activeCombine.recordedInput[currentFrame] = inputs;
				} else {
					if (currentFrame < combine.recordedInput.length) {
						inputs = combine.recordedInput[currentFrame];
					}
				}
				if (inputs.contains(Forward)) {
					if (inputs.contains(TurnLeft)) {
						combine.obj.rotation -= FRAME_TIME * 1.0;
					}
					if (inputs.contains(TurnRight)) {
						combine.obj.rotation += FRAME_TIME * 1.0;
					}

					final vel = Utils.direction(combine.obj.rotation).multiply(FRAME_TIME * 50.0);
					combine.obj.setPos(Utils.point(combine.obj).add(vel));

					final bounds = combine.cutter.getBounds(this);
					final xMin = Math.floor(bounds.xMin / FIELD_TILE_SIZE);
					final xMax = Math.ceil(bounds.xMax / FIELD_TILE_SIZE);
					final yMin = Math.floor(bounds.yMin / FIELD_TILE_SIZE);
					final yMax = Math.ceil(bounds.yMax / FIELD_TILE_SIZE);

					final localBounds = combine.cutter.getBounds(combine.cutter);
					final p = new Polygon([
						globalToLocal(combine.cutter.localToGlobal(new Point(localBounds.xMin, localBounds.yMin))),
						globalToLocal(combine.cutter.localToGlobal(new Point(localBounds.xMax, localBounds.yMin))),
						globalToLocal(combine.cutter.localToGlobal(new Point(localBounds.xMax, localBounds.yMax))),
						globalToLocal(combine.cutter.localToGlobal(new Point(localBounds.xMin, localBounds.yMax)))
					]);
					final collider = p.getCollider();

					for (y in yMin...yMax + 1) {
						for (x in xMin...xMax + 1) {
							final element = fieldElements.get(new Point2d(x, y));
							if (element != null
								&& collider.contains(new Point(x * FIELD_TILE_SIZE, y * FIELD_TILE_SIZE))
								&& element.e.t == element.fullTile) {
								completedFields++;
								element.e.t = element.emptyTile;
							}
						}
					}
				}
				if (completedFields == numFields) {
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
	}
}
