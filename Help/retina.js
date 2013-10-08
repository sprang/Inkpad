function highdpi_init() {
    // Feature detect for hi-res devices
    var hiRes = window.devicePixelRatio > 1 ? true : false;
    // Replace imgs with hi-res version .hi-res class is detected
    if (hiRes) {
        var els = jQuery("img").get();
        for(var i = 0; i < els.length; i++) {
            var src = els[i].src;
            //alert(src);
            src = src.replace(".jpg", "@2x.jpg");
            src = src.replace(".png", "@2x.png");
            src = src.replace(".gif", "@2x.gif");
            els[i].src = src;
        }
    }
}