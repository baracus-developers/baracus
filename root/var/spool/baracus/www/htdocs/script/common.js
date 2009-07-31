var sURL = unescape(window.location.pathname+window.location.search);

function verifyDelete( selVal)
{
	var agree=confirm("Confirm Delete of: " + selVal.value);
	if (agree)
		return true ;
	else
		return false ;
}

function enableISO( box)
{
	if( box.checked)
	{
		box.form.user.disabled = 0;
		box.form.pass.disabled = 0;
	}
	else
	{
		if( box.form.proxy.checked == 0)
		{
			box.form.user.value = "username";
			box.form.pass.value = "password";
			box.form.user.disabled = 1;
			box.form.pass.disabled = 1;
		}
		else
		{
			box.form.iso.checked = 1;
			alert( "'Download ISO' must be enabled if 'Use Proxy' is enabled.");
		}
	}
}

function enableProxy( box)
{
	if( box.checked)
	{
		box.form.puser.disabled = 0;
		box.form.ppass.disabled = 0;
		box.form.paddr.disabled = 0;
		box.form.iso.checked = 1;
		enableISO( box.form.iso);
	}
	else
	{
		box.form.puser.value = "username";
		box.form.ppass.value = "password";
		box.form.paddr.value = "hostname";
		box.form.puser.disabled = 1;
		box.form.ppass.disabled = 1;
		box.form.paddr.disabled = 1;
	}
}

function clearText( text)
{
	text.value = "";
}

function jsTest()
{
 	alert("LSG common.js is working!");	
}

function scrollDown()
{
	e = document.getElementById("tscroll");
	e.scrollTop = e.scrollHeight;
	doLoad("", "");
}

function toggleRefresh()
{
	var rURL;

	rURL = sURL.replace( "ref=off", "ref=on");
	if( rURL == sURL)
	{
		rURL = sURL.replace( "ref=on", "ref=off");
	}
	refresh( rURL);
}

function procChange()
{
	var selection = document.form1.current.value;
	var url = "/baracus/ba/procCurrent?cur=" + selection + "&ref=off";
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

function profUpdate()
{
	var selection = document.profList.profile.value;
	var url = "/baracus/ba/createContent?caller=create&attr=profile&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function distUpdate()
{
	var selection = document.createAdd.distro.value;
	var url = "/baracus/ba/createContent?caller=create&attr=distro&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function templateUpdate( select)
{
	var selection = select.value;
	var url = "/baracus/ba/createContent?caller=create&attr=template&val=" + selection;
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

function hwUpdate( sel)
{
	var selection = sel.value;
	var url = "/baracus/ba/createContent?caller=create&attr=hardware&val=" + selection;
	document.getElementById("infoBox").src=url;
}
function doLoad( rURL, qString)
{
	var myURL;
	
	if( rURL == '')
	{
		myURL = sURL;
	}
	else
	{
		myURL = rURL;
	} 
    myURL = myURL + qString;
    rfunc = "refresh( '" + myURL + "')";
    setTimeout( rfunc, 5*1000 );
}

function refresh( newURL)
{
    if( newURL == '')
    {
    	newURL = sURL;
    }
    window.location.href = newURL;
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
