// this sets the background color of the master UIView (when there are no windows/tab groups on it)
Titanium.UI.setBackgroundColor('#000');

var window = Titanium.UI.createWindow();
var overlay = Titanium.UI.createView({
	center:{x:0, y:0},
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
	detected:function(e){
		var found_a = false;
		for(var i in e.markers){
			var marker = e.markers[i];
			if(marker.code == 0x9f9f) // is mark 'A'?
			{
				var t = Ti.UI.create3DMatrix();
				
				t.m11 = marker.transform.m11;
				t.m12 = marker.transform.m12;
				t.m13 = marker.transform.m13;
				t.m14 = marker.transform.m14;
				t.m21 = marker.transform.m21;
				t.m22 = marker.transform.m22;
				t.m23 = marker.transform.m23;
				t.m24 = marker.transform.m24;
				t.m31 = marker.transform.m31;
				t.m32 = marker.transform.m32;
				t.m33 = marker.transform.m33;
				t.m34 = marker.transform.m34;
				t.m41 = marker.transform.m41;
				t.m42 = marker.transform.m42;
				t.m43 = marker.transform.m43;
				t.m44 = marker.transform.m44;

				overlay.animate({ transform:t, duration:0 });
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

