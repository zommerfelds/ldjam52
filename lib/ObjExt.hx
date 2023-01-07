// This file is part of https://github.com/zommerfelds/herbal-tea-framework
// Avoid making game-specific changes to this file. Contribute back if possible!
import Utils.Float2d;
import h2d.Object;

class ObjExt {
	public static function setPos(obj:Object, pos:Float2d) {
		obj.x = pos.x;
		obj.y = pos.y;
	}

	public static function setPosFrom(toObj:h2d.Object, fromObj:h2d.Object) {
		toObj.x = fromObj.x;
		toObj.y = fromObj.y;
	}

	public static function setTransformFrom(toObj:h2d.Object, fromObj:h2d.Object) {
		setPosFrom(toObj, fromObj);
		toObj.scaleX = fromObj.scaleX;
		toObj.scaleY = fromObj.scaleY;
		toObj.rotation = fromObj.rotation;
	}
}