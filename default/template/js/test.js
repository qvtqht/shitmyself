<HTML>
<HEAD>
	<TITLE>Form object example</TITLE>
</HEAD>
<SCRIPT>
<!--
function setCase (caseSpec){
	if (caseSpec == "upper") {
		document.form1.firstName.value=document.form1.firstName.value.toUpperCase()
		document.form1.lastName.value=document.form1.lastName.value.toUpperCase()
		document.form1.output.value=document.form1.output.value.toUpperCase()
	} else {
		document.form1.firstName.value=document.form1.firstName.value.toLowerCase()
		document.form1.lastName.value=document.form1.lastName.value.toLowerCase()
		document.form1.output.value=document.form1.output.value.toLowerCase()
	}
}

var worldString="Hello, world"

document.write(worldString.small())
document.write("<P>" + worldString.big())
document.write("<P>" + worldString.fontsize(7))
alert(worldString.fontsize(7).fontsize(3));


// -->
</SCRIPT>
<BODY>
<FORM NAME="form1">
<B>First name:</B>
<INPUT TYPE="text" NAME="firstName" SIZE=20>
<BR><B>Last name:</B>
<INPUT TYPE="text" NAME="lastName" SIZE=20>
<P><INPUT TYPE="button" VALUE="Names to uppercase" NAME="upperButton"
   onClick="setCase('upper')">
<INPUT TYPE="button" VALUE="Names to lowercase" NAME="lowerButton"
   onClick="setCase('lower')">
<P><TEXTAREA NAME=output COLS=80 ROWS=24></TEXTAREA>
</FORM>
<SCRIPT>
	document.form1.output.value="<pre>\nx   x xxxxx\nx   x   x\nxxxxx   x\nx   x   x\nx   x xxxxx\n</pre>";
</SCRIPT>
</BODY>
</HTML>
