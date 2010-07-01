var listStyle = "b";
var rName = "undefined";
var lName = "undefined";
var cName = "undefined";
var disColor = "white";
var enaColor = "#6DB33F";
var leftaddlist = new Array();
var leftrmlist = new Array();
var rightaddlist = new Array();
var rightrmlist = new Array();
	
function initColsLRB( style) {
        listStyle = style;
        cName = getCenter().name;
        if( style == "r" || style == "b")
        {
                getRightAddList().value = '';
                getRightRmList().value = '';
                rName = getRight().name;
        }
        if( style == "l" || style == "b")
        {
                getLeftAddList().value = '';
                getLeftRmList().value = '';
                lName = getLeft().name;
        }
}

function selectNone( list) {
	for (var i = 0; i < list.length; i++){
		list.options[i].selected = false;
	}
}

function selectLast( list) {
	selectNone(list);
	list.options[list.length - 1].selected = true;
}

function clearList( list)
{
	for (var i = 0; i < list.length; i++){
		list.remove(i);
	}
}

function addItem(list, strText)
{
	var newOpt;
    newOpt = document.createElement("OPTION");
	newOpt = new Option(strText,strText);
	newOpt.name=strText;
	newOpt.value=strText;
	list.options.add(newOpt);
	selectLast( list);
}

function removeItem(list, strText)
{
  var intIndex = getItemIndex(list, strText);
  if (intIndex != -1)
    list.remove(intIndex);
}

function removeCurrent( list)
{
	list.remove( list.selectedIndex);
}

function getItemIndex(objListBox, strText)
{
  for (var i = 0; i < objListBox.children.length; i++)
  {
    var strCurrentValueId = objListBox.children[i].value;
    if (strText == strCurrentValueId)
    {
      return i;
    }
  }
  return -1;
}

function getSelectedItem( list) {

	var len = list.length;
	var i = 0;
	var chosen = "";
	
	for (i = 0; i < len; i++) {
		if (list.options[i].selected) {
			chosen = chosen + list.options[i].value;
		} 
	}
	return chosen;
}

function getSize(list){
    /*
	 * Mozilla ignores whitespace, IE doesn't - count the elements in the list
	 */
    var len = list.childNodes.length;
    var nsLen = 0;
    // nodeType returns 1 for elements
    for(i=0; i<len; i++){
        if(list.childNodes.item(i).nodeType==1)
            nsLen++;
    }
    if(nsLen<2)
        return 2;
    else
        return nsLen;
}
 
function colEventHandler( name)
{
    if ( listStyle == "b" || listStyle == "l" ) {
        if( name == cTOl().name)	{
            var value = getSelectedItem( getCenter());
            if( value != "") {					
                addItem( getLeft(), value);
                pushLeftAddList( value );
                removeCurrent( getCenter());
                colSelectHandler( lName);
            }
        }
        else if ( name == lTOc().name) {
            var value = getSelectedItem( getLeft());
            if( value != "") {
                addItem( getCenter(), value);
                popLeftAddList( value );
                removeCurrent( getLeft());
                colSelectHandler( cName);
            }
        }
    }
    if ( listStyle == "b" || listStyle == "r" ) {
	    if( name == cTOr().name) {
            var value = getSelectedItem( getCenter());
            if( value != "") {
                addItem( getRight(), value);
                pushRightAddList( value );
                removeCurrent( getCenter());
                colSelectHandler( rName);
            }
        }
        else if ( name == rTOc().name) {
            var value = getSelectedItem( getRight());
            if( value != "") {
                addItem( getCenter(), value);
                popRightAddList( value );
                removeCurrent( getRight());
                colSelectHandler( cName);
            }
        }
	}
}

function colSelectHandler( name)
{
	if( name == cName)
	{
        if ( listStyle == "b" || listStyle == "l" ) {

		selectNone( getLeft());
		cTOl().disabled = false;
		lTOc().disabled = true;
		cTOl().style.color = enaColor;
		lTOc().style.color = disColor;

        }

        if ( listStyle == "b" || listStyle == "r" ) {

		selectNone( getRight());
		cTOr().disabled = false;
		rTOc().disabled = true;
		cTOr().style.color = enaColor;
		rTOc().style.color = disColor;
        }

	}
	else if ( name == lName)
	{

		selectNone( getCenter());
		cTOl().disabled = true;
		lTOc().disabled = false;
		cTOl().style.color = disColor;
		lTOc().style.color = enaColor;

        if ( listStyle == "b" ) {
		selectNone( getRight());
		cTOr().disabled = true;
		rTOc().disabled = true;
		cTOr().style.color = disColor;		
		rTOc().style.color = disColor;
        }

	}
	else if( name == rName)
	{

        if ( listStyle == "b" ) {
		selectNone( getLeft());
		cTOl().disabled = true;
		lTOc().disabled = true;
		cTOl().style.color = disColor;
		lTOc().style.color = disColor;
        }

		selectNone( getCenter());
		cTOr().disabled = true;
		rTOc().disabled = false;
		cTOr().style.color = disColor;		
		rTOc().style.color = enaColor;
	}
}

function initCols()
{
	selectNone( getCenter());
	
    if ( listStyle == "b" || listStyle == "l" ) {
	clearList( getLeft());
	cTOl().disabled = true;
	lTOc().disabled = true;
	cTOl().style.color = disColor;
	lTOc().style.color = disColor;
    }

    if ( listStyle == "b" || listStyle == "r" ) {
	clearList( getRight());
	cTOr().disabled = true;
	rTOc().disabled = true;
	cTOr().style.color = disColor;		
	rTOc().style.color = disColor;
    }
}

function getLeftList( delim)
{
	var r = "";
	for( var i = 0; i < getLeft().length; i++)
	{
		if( i != 0){
			r = r + delim;
		}
		r = r + getLeft().options[i].value;
	}
	return r;
}

function getRightList( delim)
{
	var r = "";
	for( var i = 0; i < getRight().length; i++)
	{
		if( i != 0){
			r = r + delim;
		}
		r = r + getRight().options[i].value;
	}
	return r;
}

function getListToString( liststr, delim)
{
	var r = "";

    if ( liststr == "la" ) {
            r = leftaddlist.toString();
    } else if  ( liststr == "lr" ) {
            r = leftrmlist.toString();
    } else if ( liststr == "ra" ) {
            r = rightaddlist.toString();
    } else if  ( liststr == "rr" ) {
            r = rightrmlist.toString();
    } else {
            r = "";
    }
	return r;
}

function getIndexOfValueInList( value, list )
{
	for( var i = 0; i < list.length; i++)
	{
		if( list[i] == value ){
                return i;
		}
	}
    return -1;
}

function pushLeftAddList( value )
{
        var index = getIndexOfValueInList( value, leftrmlist  );

        if ( index == -1 ) {
                leftaddlist.push( value );
        } else {
                leftrmlist.splice(index, 1);
        }
}
function popLeftAddList( value )
{
        var index = getIndexOfValueInList( value, leftaddlist  );

        if ( index == -1 ) {
                leftrmlist.push( value );
        } else {
                leftaddlist.splice(index, 1);
        }
}

function pushRightAddList( value )
{
        var index = getIndexOfValueInList( value, rightrmlist  );

        if ( index == -1 ) {
                rightaddlist.push( value );
        } else {
                rightrmlist.splice(index, 1);
        }
}
function popRightAddList( value )
{
        var index = getIndexOfValueInList( value, rightaddlist  );

        if ( index == -1 ) {
                rightrmlist.push( value );
        } else {
                rightaddlist.splice(index, 1);
        }
}

