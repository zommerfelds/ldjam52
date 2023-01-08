import Gui.Text;
import Gui.TextButton;
import Gui.TileButton;
import Utils.Point2d;
import differ.Collision;
import h2d.Anim;
import h2d.Bitmap;
import h2d.Graphics;
import h2d.Interactive;
import h2d.Object;
import h2d.SpriteBatch;
import h2d.Tile;
import h2d.TileGroup;
import h2d.col.Point;
import h3d.Vector;
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
	Backward;
}

typedef Combine = {
	obj:Object,
	anim:Anim,
	cutter:Object,
	hitBox:Object,
	startPos:Point,
	startRotation:Float,
	wheels:Array<Object>,
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
	var statusText:Text;

	static final FRAME_TIME = 1 / 60.0;
	static final FIELD_TILE_SIZE = 6;

	final fieldElements = new HashMap<Point2d, {e:BatchElement, fullTile:Tile, emptyTile:Tile}>();
	var completedFields = 0;
	var numFields = 0;
	final fieldTiles = Res.field_tiles.toTile().gridFlatten(FIELD_TILE_SIZE, FIELD_TILE_SIZE * -0.5, FIELD_TILE_SIZE * -0.5);
	final fieldTilesFull = [0, 1, 2];
	final fieldTilesEmpty = [3, 4, 5];
	final fieldTilesGrass = [6, 7, 8];
	final fieldTileFence = 9;

	public function new(levelIndex) {
		super();
		this.levelIndex = levelIndex;

		levelData = App.ldtkProject.levels[levelIndex];
	}

	override function init() {
		App.instance.engine.backgroundColor = 0xccdb5e;
		x = 20;
		y = 60;
		scale(2);

		addEventListener(onEvent);

		final pixels = Res.loader.loadCache(levelData.bgImageInfos.relFilePath, Image).getPixels();
		final field = new SpriteBatch(Res.field_tiles.toTile(), this);
		final staticTiles = new TileGroup(Res.field_tiles.toTile(), this);
		for (x in 0...pixels.height) {
			for (y in 0...pixels.width) {
				switch (pixels.getPixel(x, y) & 0xFFFFFF) {
					case 0x000000:
						final fullTile = fieldTiles[fieldTilesFull[Std.random(fieldTilesFull.length)]];
						final emptyTile = fieldTiles[fieldTilesEmpty[Std.random(fieldTilesEmpty.length)]];
						final element = new BatchElement(fullTile);
						element.x = x * FIELD_TILE_SIZE;
						element.y = y * FIELD_TILE_SIZE;
						field.add(element);
						fieldElements.set(new Point2d(x, y), {e: element, fullTile: fullTile, emptyTile: emptyTile});
						numFields++;
					case 0xff0000:
						final fenceTile = fieldTiles[fieldTileFence];
						staticTiles.add(x * FIELD_TILE_SIZE, y * FIELD_TILE_SIZE, fenceTile);
						fieldElements.set(new Point2d(x, y), {e: null, fullTile: fenceTile, emptyTile: null});

					default:
						final grassTile = fieldTiles[fieldTilesGrass[Std.random(fieldTilesGrass.length)]];
						staticTiles.add(x * FIELD_TILE_SIZE, y * FIELD_TILE_SIZE, grassTile);
				}
			}
		}

		levelData.l_Props.render(staticTiles);

		final combineFrames = Res.combine.toTile().gridFlatten(64, -54, -32);

		for (combineData in levelData.l_Entities.all_Combine) {
			final combineObj = new Object(this);
			combineObj.x = combineData.pixelX;
			combineObj.y = combineData.pixelY;
			combineObj.rotation = combineData.f_Rotation;

			final wheelTile = Res.combine_parts.toTile().sub(0, 0, 16, 16, -8, -8);
			final wheelL = new Bitmap(wheelTile, combineObj);
			wheelL.x = -38;
			wheelL.y = 15;
			final wheelR = new Bitmap(wheelTile, combineObj);
			wheelR.x = wheelL.x;
			wheelR.y = -wheelL.y;

			final anim = new Anim(combineFrames, 25, combineObj);

			// A bit of a hacky way to set the collision shape that cuts the crops.
			final cutterOffset = new Object(combineObj);
			cutterOffset.x = 0;
			final cutterTile = Tile.fromColor(0x000000, 10, 60);
			cutterTile.setCenterRatio();
			final cutter = new Bitmap(cutterTile, cutterOffset);
			cutter.visible = false;
			cutter.alpha = 0.5;

			final hitBoxOffset = new Object(combineObj);
			hitBoxOffset.x = -20;
			final hitBoxTile = Tile.fromColor(0x000000, 50, 39);
			hitBoxTile.setCenterRatio();
			final hitBox = new Bitmap(hitBoxTile, hitBoxOffset);
			hitBox.visible = false;
			hitBox.alpha = 0.5;

			final combine:Combine = {
				obj: combineObj,
				anim: anim,
				hitBox: hitBox,
				cutter: cutter,
				startPos: Utils.point(combineObj),
				startRotation: combineObj.rotation,
				recordedInput: [],
				wheels: [wheelL, wheelR]
			};
			final interactive = new Interactive(combineFrames[0].width, combineFrames[0].height, combineObj);
			interactive.x += combineFrames[0].dx;
			interactive.y += combineFrames[0].dy;
			// interactive.backgroundColor = 0xffff0000;
			interactive.onClick = e -> {
				activeCombine = combine;
				// combine.recordedInput = [];
				selectedHighlight.visible = true;
				combine.obj.addChild(selectedHighlight);
				paused = true;
				anim.colorAdd = new Vector(0.2, 0.2, 0.2);
				for (c in combines) {
					if (c.anim == anim)
						continue;
					c.anim.colorAdd = null;
				}
				// resetTime();
			};
			/*final select = new Graphics(combineObj);
				select.beginFill(0xffffffff, 0.3);
				select.drawCircle(-20, 0, combineFrames[0].width * 0.6); */
			new FuncObject(() -> {
				interactive.visible = (currentFrame == 0);
				// select.visible = (activeCombine == null);
			}, combineObj);
			combines.push(combine);
		}

		// selectedHighlight.lineStyle(2, 0xffffffff);
		// selectedHighlight.drawCircle(-20, 0, combineFrames[0].width * 0.6);

		final BUTTON_TILE_SIZE = 11;
		/*
			final buttonPlayTile = Res.buttons.toTile()
				.sub(0 * BUTTON_TILE_SIZE, 0, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE * -0.5, BUTTON_TILE_SIZE * -0.5);
			final buttonPlay = new TileButton(buttonPlayTile, this, () -> {
				paused = false;
			});
			buttonPlay.x = 880;
			buttonPlay.y = 300;
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
		final buttonBackTile = Res.buttons.toTile().sub(1 * BUTTON_TILE_SIZE, 0, BUTTON_TILE_SIZE, BUTTON_TILE_SIZE);
		final buttonBack = new TileButton(buttonBackTile, this, () -> {
			activeCombine = null;
			for (c in combines) {
				c.anim.colorAdd = null;
			}
			selectedHighlight.visible = false;
			paused = true;
			resetTime();
		});
		buttonBack.content.padding = 0;
		// buttonBack.content.paddingBottom = 10;
		buttonBack.content.horizontalAlign = Middle;
		buttonBack.content.minHeight = 60;
		buttonBack.content.minWidth = 60;
		buttonBack.redrawButton();
		buttonBack.x = 795;
		buttonBack.y = 200;
		final buttonReset = new TextButton(this, "RESET", () -> {
			activeCombine = null;
			for (c in combines) {
				c.anim.colorAdd = null;
				c.recordedInput = [];
			}
			selectedHighlight.visible = false;
			paused = true;
			resetTime();
		}, 0x000000, false, 0.25);
		buttonReset.content.padding = 0;
		// buttonReset.content.paddingBottom = 10;
		buttonReset.content.horizontalAlign = Middle;
		buttonReset.content.minHeight = 60;
		buttonReset.content.minWidth = 100;
		buttonReset.redrawButton();
		buttonReset.x = 870;
		buttonReset.y = 200;

		final buttonMenu = new TextButton(this, "MENU", () -> {
			App.instance.switchState(new LevelSelectView());
		}, 0x000000, true, 0.25);
		buttonMenu.content.padding = 0;
		// buttonMenu.content.paddingBottom = 10;
		buttonMenu.content.horizontalAlign = Middle;
		buttonMenu.content.minHeight = 60;
		buttonMenu.content.minWidth = 100;
		buttonMenu.redrawButton();
		buttonMenu.x = 1040;
		buttonMenu.y = 200;

		statusText = new Text("", this, 0.3);
		statusText.textColor = 0x000000;
		statusText.x = 800;
		statusText.y = 290;
		statusText.maxWidth = 350;

		final gr = new Graphics(this);
		gr.lineStyle(1, 0x000000);
		gr.drawRect(-0.5 * FIELD_TILE_SIZE, -0.5 * FIELD_TILE_SIZE, 128 * FIELD_TILE_SIZE, 128 * FIELD_TILE_SIZE);

		final zoomOut = new TextButton(this, "zoom out", () -> {
			scale(0.8);
		}, 0x000000, false, 0.15);
		zoomOut.content.padding = 15;
		zoomOut.redrawButton();
		zoomOut.x = 0;
		zoomOut.y = -20;

		final zoomIn = new TextButton(this, "zoom in", () -> {
			scale(1 / 0.8);
		}, 0x000000, false, 0.15);
		zoomIn.content.padding = 15;
		zoomIn.redrawButton();
		zoomIn.x = 100;
		zoomIn.y = -20;
	}

	function resetTime() {
		currentFrame = 0;
		timeAcc = 0;
		completedFields = 0;
		for (e in fieldElements) {
			if (e.e != null) {
				e.e.t = e.fullTile;
			}
		}
		for (c in combines) {
			c.obj.setPos(c.startPos);
			c.obj.rotation = c.startRotation;
		}
	}

	function onEvent(event:hxd.Event) {}

	override function update(dt:Float) {
		final color = currentFrame * FRAME_TIME <= levelData.f_timeLimit ? '#128a1c' : '#99300c';
		statusText.text = 'Time: <font color="$color">' + MyUtils.formatTime(currentFrame * FRAME_TIME) + "</font><br/>" + "Goal: "
			+ MyUtils.formatTime(levelData.f_timeLimit) + "<br/>" + "Progress: " + Utils.floatToStr(completedFields / numFields * 100, 1) + "%";
		if (paused) {
			statusText.text += "<br/><br/>";
			if (activeCombine == null) {
				statusText.text += "Click on a combine harvester to start.";
			} else {
				statusText.text += "Press the UP key to move.";
			}
		}

		for (combine in combines) {
			combine.anim.pause = paused || combine.recordedInput.empty();
		}

		if (Key.isDown(Key.UP) || Key.isDown(Key.DOWN)) {
			paused = false;
		}
		if (paused)
			return;

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
					if (Key.isDown(Key.DOWN)) {
						inputs.push(Backward);
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
				for (w in combine.wheels) {
					w.rotation = 0.0;
				}
				final originalPos = Utils.point(combine.obj);
				final originalRotation = combine.obj.rotation;
				var vel = null;
				if (inputs.contains(TurnLeft)) {
					for (w in combine.wheels) {
						w.rotation = 0.4;
					}
				}
				if (inputs.contains(TurnRight)) {
					for (w in combine.wheels) {
						w.rotation = -0.4;
					}
				}
				if (inputs.contains(Forward)) {
					if (inputs.contains(TurnLeft)) {
						combine.obj.rotation -= FRAME_TIME * 1.0;
					}
					if (inputs.contains(TurnRight)) {
						combine.obj.rotation += FRAME_TIME * 1.0;
					}
				}
				if (inputs.contains(Backward)) {
					if (inputs.contains(TurnLeft)) {
						combine.obj.rotation += FRAME_TIME * 1.0;
					}
					if (inputs.contains(TurnRight)) {
						combine.obj.rotation -= FRAME_TIME * 1.0;
					}
				}

				if (inputs.contains(Forward)) {
					vel = Utils.direction(combine.obj.rotation).multiply(FRAME_TIME * 50.0);
				}
				if (inputs.contains(Backward)) {
					vel = Utils.direction(combine.obj.rotation).multiply(-FRAME_TIME * 50.0);
				}

				if (vel != null) {
					combine.obj.setPos(originalPos.add(vel));

					final shape = getShape(combine.hitBox);
					for (other in combines) {
						if (combine == other)
							continue;
						final shapeOther = getShape(other.hitBox);
						if (Collision.shapeWithShape(shape, shapeOther) != null) {
							combine.obj.setPos(originalPos);
							combine.obj.rotation = originalRotation;
							inputs.splice(0, inputs.length); // This will also change the recording, since it's the same reference.
							break;
						}
					}
				}
				{
					final bounds = combine.hitBox.getBounds(this);
					final xMin = Math.floor(bounds.xMin / FIELD_TILE_SIZE);
					final xMax = Math.ceil(bounds.xMax / FIELD_TILE_SIZE);
					final yMin = Math.floor(bounds.yMin / FIELD_TILE_SIZE);
					final yMax = Math.ceil(bounds.yMax / FIELD_TILE_SIZE);
					final hitBoxShape = getShape(combine.hitBox);
					for (y in yMin...yMax + 1) {
						for (x in xMin...xMax + 1) {
							final element = fieldElements.get(new Point2d(x, y));
							if (element != null
								&& Collision.pointInPoly(x * FIELD_TILE_SIZE, y * FIELD_TILE_SIZE, hitBoxShape)
								&& element.fullTile == fieldTiles[fieldTileFence]) {
								combine.obj.setPos(originalPos);
								combine.obj.rotation = originalRotation;
								inputs.splice(0, inputs.length); // This will also change the recording, since it's the same reference.
								break;
							}
						}
					}
				}
				if (inputs.contains(Forward)) {
					final bounds = combine.cutter.getBounds(this);
					final xMin = Math.floor(bounds.xMin / FIELD_TILE_SIZE);
					final xMax = Math.ceil(bounds.xMax / FIELD_TILE_SIZE);
					final yMin = Math.floor(bounds.yMin / FIELD_TILE_SIZE);
					final yMax = Math.ceil(bounds.yMax / FIELD_TILE_SIZE);
					final cutterShape = getShape(combine.cutter);
					for (y in yMin...yMax + 1) {
						for (x in xMin...xMax + 1) {
							final element = fieldElements.get(new Point2d(x, y));
							if (element != null
								&& Collision.pointInPoly(x * FIELD_TILE_SIZE, y * FIELD_TILE_SIZE, cutterShape)
								&& element.e != null
								&& element.e.t == element.fullTile) {
								completedFields++;
								element.e.t = element.emptyTile;
							}
						}
					}
				}
				if (completedFields == numFields && currentFrame * FRAME_TIME <= levelData.f_timeLimit) {
					if (App.save.unlockedLevel < levelIndex + 1) {
						App.save.unlockedLevel = levelIndex + 1;
						App.save.levelRecords.set(levelIndex, currentFrame * FRAME_TIME);
						Save.save(App.save);
					}

					App.instance.switchState(new LevelSelectView());
					/*
						if (levelIndex + 1 < App.ldtkProject.levels.length) {
							App.instance.switchState(new PlayView(levelIndex + 1));
						} else {
							App.instance.switchState(new GameEndView());
					}*/
				}
			}
		}
	}

	function getShape(obj:Object) {
		final localBounds = obj.getBounds(obj);
		return new differ.shapes.Polygon(0, 0, [
			MyUtils.differVector(globalToLocal(obj.localToGlobal(new Point(localBounds.xMin, localBounds.yMin)))),
			MyUtils.differVector(globalToLocal(obj.localToGlobal(new Point(localBounds.xMax, localBounds.yMin)))),
			MyUtils.differVector(globalToLocal(obj.localToGlobal(new Point(localBounds.xMax, localBounds.yMax)))),
			MyUtils.differVector(globalToLocal(obj.localToGlobal(new Point(localBounds.xMin, localBounds.yMax))))
		]);
	}
}
