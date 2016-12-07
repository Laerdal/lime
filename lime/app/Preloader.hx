package lime.app;


import haxe.io.Bytes;
import haxe.io.Path;
import lime.app.Event;
import lime.Assets;
import lime.audio.AudioBuffer;

#if (js && html5)
import lime.graphics.Image;
import js.html.SpanElement;
import js.Browser;
import lime.net.HTTPRequest;
#elseif flash
import flash.display.LoaderInfo;
import flash.display.Sprite;
import flash.events.ProgressEvent;
import flash.Lib;
#end


class Preloader #if flash extends Sprite #end {
	
	
	public var complete:Bool;
	public var onComplete = new Event<Void->Void> ();
	public var onProgress = new Event<Int->Int->Void> ();
	
	#if (js && html5)
	public static var audioBuffers = new Map<String, AudioBuffer> ();
	public static var images = new Map<String, Image> ();
	public static var loaders = new Map<String, HTTPRequest<Bytes>> ();
	public static var textLoaders = new Map<String, HTTPRequest<String>> ();
	private var loaded = 0;
	private var total = 0;
	private var bytesLoaded = 0;
	private var bytesTotal = 0;
	#end
	
	
	public function new () {
		
		#if flash
		super ();
		#end
		
		onProgress.add (update);
		
	}
	
	
	public function create (config:Config):Void {
		
		#if flash
		Lib.current.addChild (this);
		
		Lib.current.loaderInfo.addEventListener (flash.events.Event.COMPLETE, loaderInfo_onComplete);
		Lib.current.loaderInfo.addEventListener (flash.events.Event.INIT, loaderInfo_onInit);
		Lib.current.loaderInfo.addEventListener (ProgressEvent.PROGRESS, loaderInfo_onProgress);
		Lib.current.addEventListener (flash.events.Event.ENTER_FRAME, current_onEnter);
		#end
		
		#if (!flash && !html5)
		start ();
		#end
		
	}
	
	
	public function load (urls:Array<String>, types:Array<AssetType>):Void {
		
		#if (js && html5)
		
		var cacheVersion = Assets.cache.version;
		var soundPaths = new Map<String, Array<String>> ();
		
		for (i in 0...urls.length) {
			
			var url = urls[i];
			
			switch (types[i]) {
				
				case IMAGE:
					
					if (!images.exists (url)) {
						
						var image = Image.fromFile (url + "?" + cacheVersion, image_onLoad, image_onLoad, progressIncrementer());
						images.set (url, image);
						total++;
						
					}
				
				case BINARY:
					
					if (!loaders.exists (url)) {
						
						var loader = new HTTPRequest<Bytes> ();
						loaders.set (url, loader);
						total++;
						
					}
				
				case TEXT:
					
					if (!textLoaders.exists (url)) {
						
						var loader = new HTTPRequest<String> ();
						textLoaders.set (url, loader);
						total++;
						
					}
				
				case MUSIC, SOUND:
					
					var soundName = Path.withoutExtension (url);
					var extension = Path.extension (url);
					
					if (!soundPaths.exists (soundName)) {
						
						soundPaths.set (soundName, []);
						total++;
						
					}
					
					if (extension == "wav") {
						
						soundPaths.get (soundName).push (url);
						
					} else {
						
						soundPaths.get (soundName).unshift (url);
						
					}
				
				case FONT:
					
					total++;
					loadFont (url);
				
				default:
				
			}
			
		}
		
		for (url in loaders.keys ()) {
			
			var loader = loaders.get (url);
			var future = loader.load (url + "?" + cacheVersion);
			future.onProgress (progressIncrementer ());
			future.onComplete (loader_onComplete);
			
		}
		for (url in textLoaders.keys ()) {
			
			var loader = textLoaders.get (url);
			var future = loader.load (url + "?" + cacheVersion);
			future.onProgress (progressIncrementer ());
			future.onComplete (loader_onComplete);
			
		}
		
		for (paths in soundPaths) {
			
			AudioBuffer.loadFromFiles (paths).onComplete (function (audioBuffer) {
				
				for (path in paths) {
					
					audioBuffers.set (path, audioBuffer);
					
				}
				
				audioBuffer_onLoad ();
				
			}).onError (audioBuffer_onLoad);
			
		}
		
		if (total == 0) {
			
			start ();
			
		}
		
		#end
		
	}
	
	
	#if (js && html5)
	private function loadFont (font:String):Void {
		
		if (untyped (Browser.document).fonts && untyped (Browser.document).fonts.load) {
			
			untyped (Browser.document).fonts.load ("1em '" + font + "'").then (function (_) {
				
				loaded ++;
				onProgress.dispatch (loaded + bytesLoaded, total + bytesTotal);
				
				if (loaded == total) {
					
					start ();
					
				}
				
			});
			
		} else {
			
			var node:SpanElement = cast Browser.document.createElement ("span");
			node.innerHTML = "giItT1WQy@!-/#";
			var style = node.style;
			style.position = "absolute";
			style.left = "-10000px";
			style.top = "-10000px";
			style.fontSize = "300px";
			style.fontFamily = "sans-serif";
			style.fontVariant = "normal";
			style.fontStyle = "normal";
			style.fontWeight = "normal";
			style.letterSpacing = "0";
			Browser.document.body.appendChild (node);
			
			var width = node.offsetWidth;
			style.fontFamily = "'" + font + "', sans-serif";
			
			var interval:Null<Int> = null;
			var found = false;
			
			var checkFont = function () {
				
				if (node.offsetWidth != width) {
					
					// Test font was still not available yet, try waiting one more interval?
					if (!found) {
						
						found = true;
						return false;
						
					}
					
					loaded ++;
					
					if (interval != null) {
						
						Browser.window.clearInterval (interval);
						
					}
					
					node.parentNode.removeChild (node);
					node = null;
					
					onProgress.dispatch (loaded + bytesLoaded, total + bytesTotal);
					
					if (loaded == total) {
						
						start ();
						
					}
					
					return true;
					
				}
				
				return false;
				
			}
			
			if (!checkFont ()) {
				
				interval = Browser.window.setInterval (checkFont, 50);
				
			}
			
		}
		
	}
	
	
	private function progressIncrementer () {
		
		var bytesLoaded = 0;
		var bytesTotal = 0;
		
		return function (numLoaded, numTotal) {
			
			if (numLoaded > bytesLoaded) {
				
				this.bytesLoaded += (numLoaded - bytesLoaded);
				bytesLoaded = numLoaded;
				
			}
			
			if (numTotal > bytesTotal) {
				
				this.bytesTotal += (numTotal - bytesTotal);
				bytesTotal = numTotal;
				
			}
			
			onProgress.dispatch (loaded + this.bytesLoaded, total + this.bytesTotal);
			
		}
	}
	#end
	
	
	private function start ():Void {
		
		complete = true;
		
		#if flash
		if (Lib.current.contains (this)) {
			
			Lib.current.removeChild (this);
			
		}
		#end
		
		onComplete.dispatch ();
		
	}
	
	
	private function update (loaded:Int, total:Int):Void {
		
		
		
	}
	
	
	
	
	// Event Handlers
	
	
	
	
	#if (js && html5)
	private function audioBuffer_onLoad (?_):Void {
		
		loaded++;
		
		onProgress.dispatch (loaded + bytesLoaded, total + bytesTotal);
		
		if (loaded == total) {
			
			start ();
			
		}
		
	}
	
	
	private function image_onLoad (_):Void {
		
		loaded++;
		
		onProgress.dispatch (loaded + bytesLoaded, total + bytesTotal);
		
		if (loaded == total) {
			
			start ();
			
		}
		
	}
	
	
	private function loader_onComplete (_:Dynamic):Void {
		
		loaded++;
		
		onProgress.dispatch (loaded + bytesLoaded, total + bytesTotal);
		
		if (loaded == total) {
			
			start ();
			
		}
		
	}
	#end
	
	
	#if flash
	private function current_onEnter (event:flash.events.Event):Void {
		
		if (!complete && Lib.current.loaderInfo.bytesLoaded == Lib.current.loaderInfo.bytesTotal) {
			
			complete = true;
			onProgress.dispatch (Lib.current.loaderInfo.bytesLoaded, Lib.current.loaderInfo.bytesTotal);
			
		}
		
		if (complete) {
			
			Lib.current.removeEventListener (flash.events.Event.ENTER_FRAME, current_onEnter);
			Lib.current.loaderInfo.removeEventListener (flash.events.Event.COMPLETE, loaderInfo_onComplete);
			Lib.current.loaderInfo.removeEventListener (flash.events.Event.INIT, loaderInfo_onInit);
			Lib.current.loaderInfo.removeEventListener (ProgressEvent.PROGRESS, loaderInfo_onProgress);
			
			start ();
			
		}
		
	}
	
	
	private function loaderInfo_onComplete (event:flash.events.Event):Void {
		
		complete = true;
		onProgress.dispatch (Lib.current.loaderInfo.bytesLoaded, Lib.current.loaderInfo.bytesTotal);
		
	}
	
	
	private function loaderInfo_onInit (event:flash.events.Event):Void {
		
		onProgress.dispatch (Lib.current.loaderInfo.bytesLoaded, Lib.current.loaderInfo.bytesTotal);
		
	}
	
	
	private function loaderInfo_onProgress (event:flash.events.ProgressEvent):Void {
		
		onProgress.dispatch (Lib.current.loaderInfo.bytesLoaded, Lib.current.loaderInfo.bytesTotal);
		
	}
	#end
	
	
}