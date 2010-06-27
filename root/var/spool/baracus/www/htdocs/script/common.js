var sURL = unescape(window.location.pathname+window.location.search);
var rURL = unescape(window.location.pathname);

function doSubmit( item)
{
	item.form.submit();
}

function verifyDelete( selVal)
{
	var agree=confirm("Confirm Delete of: " + selVal);
	if (agree)
		return true ;
	else
		return false ;
}

function verify( item, msg)
{
	if( !item.value || item.value == "" || item.value == "undefined")
	{
		alert( msg);
		return false;
	}
	return true;
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

function selectZero( s)
{
	s[0].selected = "1";
}

function selectThis( s, v)
{
	for(index = 0; index < s.length; index++)
	{
   		if( s[index].value == v)
   		{
   			s.selectedIndex = index;
   		}
   	}
}

function selectRadio( radioObj, newValue)
{
		if(!radioObj)
		{
			return;
		}
		var radioLength = radioObj.length;
		if(radioLength == undefined)
		{
			radioObj.checked = (radioObj.value == newValue.toString());
			return;
		}
		for(var i = 0; i < radioLength; i++)
		{
			radioObj[i].checked = false;
			if(radioObj[i].value == newValue.toString())
			{
				radioObj[i].checked = true;
			}
		}
}

function hostRemoveEnterKey(e, filterKey)
{
     var key;

     if(window.event)
     {
          key = window.event.keyCode;   //IE
     }
     else
     {
          key = e.which;     			//firefox
     }
     if(key == 13)
     {
          hostReload( document.form1.host.value, filterKey, document.form1.filter.value);
          return false;
     }
     else
     {
          return true;
     }
}

function hostReload( host, filterKey, filter)
{
	var url = rURL + "?host=" + host + "&filter=" + filter + "&filterKey=" + filterKey;
	refresh( url);
}

function sourceRemoveEnterKey(e)
{
     var key;

     if(window.event)
     {
          key = window.event.keyCode;   //IE
     }
     else
     {
          key = e.which;     			//firefox
     }
     if(key == 13)
     {
     	  if( document.form1.addon == undefined)
     	  {
     	  	 addon = "";
     	  }
     	  else
     	  {
     	  	addon = document.form1.addon.value;
     	  }

     	  if( document.form1.status == undefined)
     	  {
     	  	status = "";
     	  }
     	  else
     	  {
     	  	status = document.form1.status.value;
     	  }
     	  
          sourceReload( document.form1.distro.value, addon, document.form1.filter.value, status);
          return false;
     }
     else
     {
          return true;
     }
}

function sourceReload( name, addon, filter, status)
{
	var url = rURL + "?distro=" + name + "&addon=" + addon + "&filter=" + filter + "&status=" + status;
	refresh( url);
}

function configRemoveEnterKey(e, name, filter, ver)
{
        var key;

        if(window.event)
        {
                key = window.event.keyCode;   //IE
        }
        else
        {
                key = e.which;     			//firefox
        }
        if(key == 13)
        {
                configReload( name, filter, ver );
                return false;
        }
        else
        {
                return true;
        }
}

function configReload( name, filter, ver)
{
	var url = rURL
            + "?name="   + name
            + "&filter=" + filter
            + "&ver="    + ver;
	refresh( url);
}


function clearText( text)
{
	text.value = "";
}

function jsTest()
{
 	alert("LSG common.js is working!");	
}

function jsTest2( text)
{
	alert( text);
}

function scrollDown()
{
	e = document.getElementById("tscroll");
	e.scrollTop = e.scrollHeight;
	doLoad("", "", 5);
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
	

 	var myURL = rURL + "?prof=" + document.createAdd.profile.value + 
 		"&hostname=" + document.createAdd.hostname.value +
 		"&mac=" + document.createAdd.mac.value +
 		"&ip=" + document.createAdd.ip.value;
 	window.location.href = myURL;
}

function hwUpdate( sel)
{
	var selection = sel.value;
	var url = "/baracus/ba/createContent?caller=create&attr=hardware&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function autobuildUpdate( sel)
{
	var selection = sel.value;
	var url = "/baracus/ba/createContent?caller=create&attr=autobuild&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function storageUpdate( sel)
{
	var selection = sel.value;
	var url = "/baracus/ba/createContent?caller=storeNet&attr=storage&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function profUpdate( sel, tall, ver)
{
	var url = "/baracus/ba/createContent?caller=create&attr=profile&val=" + sel + "&t=" + tall + "&ver=" + ver;
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

function addonUpdate()
{
	
	var url = "/baracus/ba/createContent?caller=create&attr=addon";
	var selection = document.createAdd.addon;
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

function distUpdate( selection)
{
	var url = "/baracus/ba/createContent?caller=create&attr=distro&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function templateUpdate( select)
{
	var selection = select.value;
	var url = "/baracus/ba/createContent?caller=create&attr=template&val=" + selection;
	document.getElementById("infoBox").src=url;
}

function doLoad( rURL, qString, sec)
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
    setTimeout( rfunc, sec*1000 );
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

function setCheckedValue(radioObj, newValue) {
	if(!radioObj)
		return;
	var radioLength = radioObj.length;
	if(radioLength == undefined) {
		radioObj.checked = (radioObj.value == newValue.toString());
		return;
	}
	for(var i = 0; i < radioLength; i++) {
		radioObj[i].checked = false;
		if(radioObj[i].value == newValue.toString()) {
			radioObj[i].checked = true;
		}
	}
}

function getCheckedValue(radioObj) {
	if(!radioObj)
		return "";
	var radioLength = radioObj.length;
	if(radioLength == undefined)
		if(radioObj.checked)
			return radioObj.value;
		else
			return "";
	for(var i = 0; i < radioLength; i++) {
		if(radioObj[i].checked) {
			return radioObj[i].value;
		}
	}
	return "";
}






