import differ.math.Vector;

using StringTools;

class MyUtils {
	public static function differVector(pt:{x:Float, y:Float}) {
		return new Vector(pt.x, pt.y);
	}

	public static function formatTime(timeSecs:Float) {
		final date = Date.fromTime(timeSecs * 1000);
		return DateTools.format(date, "%M:%S.") + ("" + Std.int(((timeSecs) % 1.0) * 100)).lpad("0", 2);
	}
}
