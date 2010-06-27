function checkVNC( name)
{
    var element = document.getElementsByName( name);
    var type = element[0].value;
    if( type == "virsh")
    {
        document.form1.submit2.disabled=false;
        document.form1.hostname.value=element[0].id;
    }
    else
    {
        document.form1.submit2.disabled=true;
    }
}

function setTarget( target)
{
    document.form1.target = target;
}

function popResponse( id)
{
    win = window.open("",
                      "myWin",
                      "toolbar=no,directories=no,location=1,status=yes,menubar=no,resizable=no,scrollbars=no,width=300,height=150");
                                
    document.form1.action='powerHandler';
    document.form1.target='myWin';
	document.form1.mac.value = id;    
	document.form1.submit();
    return false;
}                       

function setMac()
{
    alert("Test alert");
    return true;
}
