var sURL = unescape(window.location.pathname+window.location.search);

function scrollDown()
{
	e = document.getElementById("tscroll");
	e.scrollTop = e.scrollHeight;
	doLoad("");
}
	
function jsTest()
{
 	alert("LSG common.js is working!");	
}

function procChange()
{
	var selection = document.form1.current.value;
	var url = "/baracus/ba/currentContent?cur=" + selection;
	document.getElementById("infoBox").src=url;
}

function profileChange()
{
	
 	var sURL = "/baracus/ba/hostCreate?prof=" + document.createAdd.profile.value + 
 		"&hostname=" + document.createAdd.hostname.value +
 		"&mac=" + document.createAdd.mac.value +
 		"&ip=" + document.createAdd.ip.value;
 	window.location.href = sURL;
}

function distUpdate()
{
	var selection = document.createAdd.distro.value;
	var url = "/baracus/ba/createContent?caller=create&attr=distro&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function modUpdate()
{
	
	var url = "/baracus/ba/createContent?caller=create&attr=module";
	var selection = document.createAdd.module;
	var i;
	for(i = 0; i < selection.options.length; i++)
	{
		if( selection.options[i].selected)
		{
			url = url + "&val=" + selection.options[i].value;
		}
	}
	document.getElementById("infoBox").src=url;
}

function hwUpdate()
{
	var selection = document.createAdd.hardware.value;
	var url = "/baracus/ba/createContent?caller=create&attr=hardware&val=" + selection;
	document.getElementById("infoBox").src=url;
}
function doLoad( qString)
{
    rfunc = "refresh( '" + qString + "')";
    setTimeout( rfunc, 5*1000 );
}

function refresh( qString)
{
    sURL = sURL + qString;
    window.location.href = sURL;
}

function mac_only( event) 
{
	var keynum;
	var testvar;
	var ssize = 0;
	var idx = 0;
	var adddelim = 1;			
			
	if(window.event)
	{
		keynum = event.keyCode;
	}
	else if(event.which)
	{
		keynum = event.which;
	}

	if( keynum == null || keynum == 8 || keynum == 46 || keynum == 58) // undefined, backspace, delete, :
	{
		return true;
	}

	testvar = document.createAdd.mac.value;
	
	while( idx > -1)
	{
		idx = testvar.indexOf( ":");
		ssize = testvar.length;
		if( idx > -1)
		{
			if( idx == ssize-1)
			{
				adddelim = 0;
			}
			testvar = testvar.replace(":", "");
		}
	}
	
	ssize = testvar.length;
	if( ssize == 12)
	{
		return false;
	}

	if( adddelim && ssize && !(ssize%2))
	{
		document.createAdd.mac.value = document.createAdd.mac.value + ":";
	}

	if(	(keynum < 97 || keynum > 102) && // a-z
		(keynum < 65 || keynum > 70) &&  // A-Z
		(keynum < 48 || keynum > 57)) 	 // 0-9
	{
		return false;
	}
	else
	{
		return true;
	}	
}

function set_distro()
{
	document.add.distro.value = document.dselect.distro.value;
	document.del.distro.value = document.dselect.distro.value;
}
