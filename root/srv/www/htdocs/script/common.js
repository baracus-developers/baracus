var sURL = unescape(window.location.pathname+window.location.search);

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
