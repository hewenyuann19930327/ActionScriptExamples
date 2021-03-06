package
{
	import com.adobe.utils.*;
	import com.renaun.DrawBitmapWithQuality;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display3D.*;
	import flash.display3D.textures.Texture;
	import flash.events.*;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	[SWF(width="800", height="600", frameRate="60", backgroundColor="#FFFFFF")]
	/**
	 * 
	 * @author Marco Scabia
	 * http://iflash3d.com
	 * 
	 * Texture Streaming changes by Renaun Erickson @renaun / renaun.com
	 */
	public class MipMapSample extends Sprite
	{
		[Embed( source = "checkers.png" )]
		protected const TextureBitmap:Class;
		
		protected var context3D:Context3D;
		protected var vertexbuffer:VertexBuffer3D;
		protected var indexBuffer:IndexBuffer3D; 
		protected var program:Program3D;
		protected var texture:Texture;
		protected var projectionTransform:PerspectiveMatrix3D;
		protected var cameraWorldTransform:Matrix3D;
		protected var viewTransform:Matrix3D;
		protected var cameraLinearVelocity:Vector3D;
		protected var cameraRotationVelocity:Number;
		protected var cameraRotationAcceleration:Number;
		protected var cameraLinearAcceleration:Number;
		
		protected const MAX_FORWARD_VELOCITY:Number = 0.05;
		protected const MAX_ROTATION_VELOCITY:Number = 1;
		protected const LINEAR_ACCELERATION:Number = 0.0005;
		protected const ROTATION_ACCELERATION:Number = 0.02;
		protected const DAMPING:Number = 1.09;

		private var mcMole:MoleAnimation;

		private var isDoneInitializing:Boolean = false;

		private var frameCount:int = 0;

		private var bData:BitmapData;

		private var textureBitmap:Bitmap;
		
		public function MipMapSample()
		{
			stage.stage3Ds[0].addEventListener( Event.CONTEXT3D_CREATE, initMolehill );
			stage.stage3Ds[0].requestContext3D();
			
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;			
			
			addEventListener(Event.ENTER_FRAME, onRender);
			
			stage.addEventListener( KeyboardEvent.KEY_DOWN, keyDownEventHandler );   
			stage.addEventListener( KeyboardEvent.KEY_UP, keyUpEventHandler );
		}
		
		protected function keyDownEventHandler(e:KeyboardEvent):void
		{
			switch (e.keyCode) 
			{ 
				case 37:
					cameraRotationAcceleration = -ROTATION_ACCELERATION;
					break
				case 38:
					cameraLinearAcceleration = LINEAR_ACCELERATION;
					break
				case 39:
					cameraRotationAcceleration = ROTATION_ACCELERATION;
					break;
				case 40:
					cameraLinearAcceleration = -LINEAR_ACCELERATION;
					break;
			}
		}
		
		protected function keyUpEventHandler(e:KeyboardEvent):void
		{
			switch (e.keyCode) 
			{ 
				case 37:
				case 39:
					cameraRotationAcceleration = 0;
					break
				case 38:
				case 40:
					cameraLinearAcceleration = 0;
					break
				case 49:
				case 50:
				case 51:
				case 52:
				case 53:
				case 54:
				case 55:
				case 56:
				case 57:
				case 58:
					// if (!isSmaller)
					uploadMipMap(e.keyCode-49);
					break
					
			}			
		}
		
		protected function initMolehill(e:Event):void
		{
			context3D = stage.stage3Ds[0].context3D;			
			
			context3D.enableErrorChecking = true;
			
			context3D.configureBackBuffer(800, 600, 1, true);
			
			var vertices:Vector.<Number> = Vector.<Number>([
				-0.3, 0, 0, 0, 0, // x, y, z, u, v
				0,0, 0.3, 0, 1,
				0.3, 0, 0, 1, 1,
				0, 0, -0.3, 1, 0]);
			
			// 4 vertices, of 5 Numbers each
			vertexbuffer = context3D.createVertexBuffer(4, 5);
			// offset 0, 4 vertices
			vertexbuffer.uploadFromVector(vertices, 0, 4);
			
			// total of 6 indices. 2 triangles by 3 vertices each
			indexBuffer = context3D.createIndexBuffer(6);			
			
			// offset 0, count 6
			indexBuffer.uploadFromVector (Vector.<uint>([0, 1, 2, 2, 3, 0]), 0, 6);
			
			textureBitmap = new TextureBitmap();
			/* Example of conditional logic to only create textures for 128x128 if its a smaller resolution
			// This effectively removes the 512x512 and 256x256 texture memory on the smaller device, for some savings
			if (isSmaller)
				bData = createMipMapLevelFromBitmap(textureBitmap, 2); // width/4
				texture = context3D.createTexture(bData.width, bData.height, Context3DTextureFormat.BGRA, false);
				bData.dispose();
				for (var i:int = 2; i <= 9; i++)
				{
					bData = createMipMapLevelFromBitmap(textureBitmap, i);
					texture.uploadFromBitmapData( bData, i-2 ); // Shift mipmap levels to map to 0 index
					bData.dispose();
				}
			}
			else below code
			*/
			
			// Allowing you to include the 128x128 and down textures and only pull in the higher resolution textures for larger screens
			bData = createMipMapLevelFromBitmap(textureBitmap, 0);
			texture = context3D.createTexture(bData.width, bData.height, Context3DTextureFormat.BGRA, false,2);
			
			for (var i:int = 2; i <= 9; i++)
			{
				bData = createMipMapLevelFromBitmap(textureBitmap, i);
				texture.uploadFromBitmapData( bData, i );
				bData.dispose();
			}
			
			var vertexShaderAssembler : AGALMiniAssembler = new AGALMiniAssembler();
			vertexShaderAssembler.assemble( Context3DProgramType.VERTEX,
				"m44 op, va0, vc0\n" + // pos to clipspace
				"mov v0, va1" // copy uv
			);
			var fragmentShaderAssembler : AGALMiniAssembler= new AGALMiniAssembler();
			fragmentShaderAssembler.assemble( Context3DProgramType.FRAGMENT,
				"tex ft1, v0, fs0 <2d, linear, miplinear>\n" +
				"mov oc, ft1"
			);
			
			program = context3D.createProgram();
			program.upload( vertexShaderAssembler.agalcode, fragmentShaderAssembler.agalcode);
			
			cameraWorldTransform = new Matrix3D();
			cameraWorldTransform.appendTranslation(0, 0.02, -0.3);
			viewTransform = new Matrix3D();
			viewTransform = cameraWorldTransform.clone();
			viewTransform.invert();			
			
			cameraLinearVelocity = new Vector3D();
			cameraRotationVelocity = 0;
			
			cameraLinearAcceleration = 0;
			cameraRotationAcceleration = 0;
			
			projectionTransform = new PerspectiveMatrix3D();
			var aspect:Number = 4/3;
			var zNear:Number = 0.1;
			var zFar:Number = 1000;
			var fov:Number = 45*Math.PI/180;
			projectionTransform.perspectiveFieldOfViewLH(fov, aspect, zNear, zFar);
			
			isDoneInitializing = true;
		}
		
		protected function calculateUpdatedVelocity(curVelocity:Number, curAcceleration:Number, maxVelocity:Number):Number
		{
			var newVelocity:Number;
			
			if (curAcceleration != 0)
			{
				newVelocity = curVelocity + curAcceleration;
				if (newVelocity > maxVelocity)
				{
					newVelocity = maxVelocity;
				}
				else if (newVelocity < -maxVelocity)
				{
					newVelocity = - maxVelocity;
				}
			}
			else
			{
				newVelocity = curVelocity / DAMPING;
			}
			return newVelocity;
		}
		
		protected function updateViewMatrix():void
		{
			cameraLinearVelocity.z = calculateUpdatedVelocity(cameraLinearVelocity.z, cameraLinearAcceleration, MAX_FORWARD_VELOCITY);
			cameraRotationVelocity = calculateUpdatedVelocity(cameraRotationVelocity, cameraRotationAcceleration, MAX_ROTATION_VELOCITY); 
			
			cameraWorldTransform.appendRotation(cameraRotationVelocity, Vector3D.Y_AXIS, cameraWorldTransform.position);			
			cameraWorldTransform.position = cameraWorldTransform.transformVector(cameraLinearVelocity);			
			
			viewTransform.copyFrom(cameraWorldTransform);
			viewTransform.invert();
		}
			
		
		protected function onRender(e:Event):void
		{
			
			if (!isDoneInitializing)
				return;
			if ( !context3D ) 
				return;
			
			context3D.clear ( 1, 1, 1, 1 );
			
			// vertex position to attribute register 0
			context3D.setVertexBufferAt (0, vertexbuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			// uv coordinates to attribute register 1
			context3D.setVertexBufferAt(1, vertexbuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			// assign texture to texture sampler 0
			context3D.setTextureAt(0, texture);			
			// assign shader program
			context3D.setProgram(program);
			
			updateViewMatrix();
			
			var m:Matrix3D = new Matrix3D();
			m.append(viewTransform);
			m.append(projectionTransform);
			
			context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, m, true);
			
			context3D.drawTriangles(indexBuffer);
			
			context3D.present();
		}
		
		public function uploadMipMap(mipMapLevel:int):void
		{
			bData = createMipMapLevelFromBitmap(textureBitmap, mipMapLevel);
			texture.uploadFromBitmapData( bData, mipMapLevel );
			bData.dispose();
		}
		
		public function createMipMapLevelFromBitmap(mc:Bitmap, mipLevel:int):BitmapData
		{
			var scale:Number = 1;
			var matrix:Matrix = new Matrix();
			while (mipLevel > 0)
			{
				scale = scale / 2;
				mipLevel--;
			}
			trace("mipLevel:" + mc.width*scale + "/"+ mc.height*scale);
			var bitdata:BitmapData = new BitmapData(mc.width*scale , mc.height*scale);
			matrix.scale(scale, scale);
			bitdata.draw(mc, matrix, null, null, null, true);
			return bitdata;
		}
	}
}