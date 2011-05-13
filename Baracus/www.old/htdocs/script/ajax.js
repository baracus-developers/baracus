function ajaxFunction( script, qstr, div)
{
	var xmlhttp;
	if (window.XMLHttpRequest)
  	{
	  	// code for IE7+, Firefox, Chrome, Opera, Safari
  		xmlhttp=new XMLHttpRequest();
  	}
	else if (window.ActiveXObject)
  	{
  		// code for IE6, IE5
  		xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  	}
	else
  	{
  		alert("Your browser does not support XMLHTTP!");
  	}
  	
	xmlhttp.open("POST","/baracus/ba/ax/" + script,true);
    xmlhttp.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

	xmlhttp.onreadystatechange=function()
	{
		if(xmlhttp.readyState==4)
  		{
  			updatepage( div, xmlhttp.responseText);
  		}
	}

	xmlhttp.send( qstr);
}

function updatepage( div, str)
{
    document.getElementById( div).innerHTML = str;
}
