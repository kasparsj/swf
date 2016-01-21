package;

import haxe.io.Path;
import format.swf.lite.symbols.StaticTextSymbol;
import format.swf.lite.symbols.DynamicTextSymbol;
import format.swf.lite.symbols.BitmapSymbol;
import format.swf.lite.symbols.ShapeSymbol;
import haxe.Template;
import format.swf.lite.symbols.ButtonSymbol;
import format.swf.lite.symbols.SpriteSymbol;
import format.swf.lite.symbols.SWFSymbol;
import format.swf.lite.SWFLite;
import sys.io.File;
import lime.project.Haxelib;
import lime.project.HXProject;
import lime.project.Asset;
import lime.project.AssetType;
import lime.tools.helpers.PathHelper;

class SWFLiteGenerator {

    private var targetPath:String;
    private var output:HXProject;
    private var swfLite:SWFLite;
    private var swfLiteAsset:Asset;
    public var prefix(default, default):String = "";
    private var movieClipTemplate:String;
    private var simpleButtonTemplate:String;
    private var generatedClasses:Map<Int, String> = new Map<Int, String>();

    public function new(targetPath:String, output:HXProject, swfLite:SWFLite, swfLiteAsset:Asset) {

        this.targetPath = targetPath;
        this.output = output;
        this.swfLite = swfLite;
        this.swfLiteAsset = swfLiteAsset;

        movieClipTemplate = File.getContent (PathHelper.getHaxelib (new Haxelib ("swf")) + "/templates/swf/lite/MovieClip.mtt");
        simpleButtonTemplate = File.getContent (PathHelper.getHaxelib (new Haxelib ("swf")) + "/templates/swf/lite/SimpleButton.mtt");

    }


    public function generateClasses ():Void {

        for (symbolID in swfLite.symbols.keys ()) {

            var symbol = swfLite.symbols.get (symbolID);

            var templateData = getSymbolTemplate(symbol);

            if (templateData != null && symbol.className != null) {

                generateClass(symbol, templateData);

            }

        }

    }

    private function getSymbolTemplate(symbol:SWFSymbol):String {

        if (Std.is (symbol, SpriteSymbol)) {

            return movieClipTemplate;

        } else if (Std.is (symbol, ButtonSymbol)) {

            return simpleButtonTemplate;

        }

        return null;

    }

    private function generateClass (symbol:SWFSymbol, templateData:String):String {

        var className = symbol.className;

        if (className == null) {

            className = "MovieClip_" + symbol.id;

        }

        var lastIndexOfPeriod = className.lastIndexOf (".");

        var packageName = "";
        var name = "";

        if (lastIndexOfPeriod == -1) {

            name = prefix + className;

        } else {

            packageName = className.substr (0, lastIndexOfPeriod);
            name = prefix + className.substr (lastIndexOfPeriod + 1);

        }

        packageName = packageName.toLowerCase ();
        name = name.substr (0, 1).toUpperCase () + name.substr (1);

        var classProperties = [];
        var childClasses = [];

        if (Std.is (symbol, SpriteSymbol)) {

            var spriteSymbol:SpriteSymbol = cast symbol;

            if (spriteSymbol.frames.length > 0) {

                for (object in spriteSymbol.frames[0].objects) {

                    if (object.name != null && swfLite.symbols.exists (object.symbol)) {

                        var childSymbol = swfLite.symbols.get (object.symbol);
                        var childClassName = null;

                        if (generatedClasses.exists(childSymbol.id)) {

                            childClassName = generatedClasses.get(childSymbol.id);
                            childClasses.push( { name: object.name, type: childClassName } );

                        }
                        else if (Std.is (childSymbol, SpriteSymbol)) {

                            var childSpriteSymbol:SpriteSymbol = cast childSymbol;

                            if (childSpriteSymbol.className != null) {

                                childClassName = generateClass(childSymbol, movieClipTemplate);
                                childClasses.push( { name: object.name, type: childClassName } );

                            }
                            else if (childSpriteSymbol.frames.length > 0) {

                                for (childObject in childSpriteSymbol.frames[0].objects) {

                                    if (childObject.name != null && swfLite.symbols.exists (childObject.symbol)) {

                                        childClassName = generateClass(childSymbol, movieClipTemplate);
                                        childClasses.push( { name: object.name, type: childClassName } );
                                        break;

                                    }

                                }

                            }

                            if (childClassName == null) {

                                childClassName = "openfl.display.MovieClip";

                            }

                        } else if (Std.is (childSymbol, ShapeSymbol)) {

                            childClassName = "openfl.display.Shape";

                        } else if (Std.is (childSymbol, BitmapSymbol)) {

                            childClassName = "openfl.display.Bitmap";

                        } else if (Std.is (childSymbol, DynamicTextSymbol) || Std.is (childSymbol, StaticTextSymbol)) {

                            childClassName = "openfl.text.TextField";

                        } else if (Std.is (childSymbol, ButtonSymbol)) {

                            childClassName = "openfl.display.SimpleButton";

                        }

                        if (childClassName != null) {

                            classProperties.push ( { name: object.name, type: childClassName } );

                        }

                    }

                }

            }

        }

        var context = { PACKAGE_NAME: packageName, CLASS_NAME: name, SWF_ID: swfLiteAsset.id, SYMBOL_ID: symbol.id, CLASS_PROPERTIES: classProperties, CHILD_CLASSES: childClasses };
        var template = new Template (templateData);

        var templateFile = new Asset ("", PathHelper.combine (targetPath, Path.directory (className.split (".").join ("/"))) + "/" + name + ".hx", AssetType.TEMPLATE);
        templateFile.data = template.execute (context);
        output.assets.push (templateFile);

        var qualifiedClassName:String = (packageName.length > 0 ? packageName + "." : "") + name;
        generatedClasses.set(symbol.id, qualifiedClassName);

        return qualifiedClassName;

    }


}