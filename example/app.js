// this sets the background color of the master UIView (when there are no windows/tab groups on it)
Titanium.UI.setBackgroundColor('#000');

var window = Titanium.UI.createWindow();
var overlay = Titanium.UI.createView({
	center:{x:0,y:0},
	width:82,
	height:82,
	backgroundColor:'#fff',
	borderRadius:12,
	borderWidth:1,
	borderColor:'#fff',
	opacity:0.9,
	visible:true
});
var label = Titanium.UI.createLabel({
	text:'a',
	font:{fontSize:60},
	width:'auto',
	height:'auto',
	textAlign:'center'
});
overlay.add(label);

var armarker = require('com.armarkerti');
var cameraView = armarker.createCameraView({
	debug:false,
	detected:function(e){
		var found_a = false;
		for(var i in e.markers){
			var marker = e.markers[i];
			if(marker.code == 0x9f9f)
			{
				var transform = Ti.UI.create3DMatrix();
				
				transform.m11 = marker.transform.m11;
				transform.m12 = marker.transform.m12;
				transform.m13 = marker.transform.m13;
				transform.m14 = marker.transform.m14;
				transform.m21 = marker.transform.m21;
				transform.m22 = marker.transform.m22;
				transform.m23 = marker.transform.m23;
				transform.m24 = marker.transform.m24;
				transform.m31 = marker.transform.m31;
				transform.m32 = marker.transform.m32;
				transform.m33 = marker.transform.m33;
				transform.m34 = marker.transform.m34;
				transform.m41 = 0;
				transform.m42 = 0;
				transform.m43 = 0;
				transform.m44 = marker.transform.m44;
				
				overlay.animate({center:{x:marker.moment.x, y:marker.moment.y}, transform:transform, duration:10 });
				
				found_a = true;
				break;
			}
		}
		overlay.visible = found_a;	
	}
});
cameraView.add(overlay);

window.add(cameraView);
window.open();

