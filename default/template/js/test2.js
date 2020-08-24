<SCRIPT LANGUAGE="JavaScript">
function displayAlert() {
   alert("5 seconds have elapsed since the button was clicked.")
}
</SCRIPT>
<BODY>
<FORM>
Click the button on the left for a reminder in 5 seconds; 
click the button on the right to cancel the reminder before 
it is displayed.
<P>
<INPUT TYPE="button" VALUE="5-second reminder"
   NAME="remind_button"
   onClick="timerID=setTimeout('displayAlert()',5000)">
<INPUT TYPE="button" VALUE="Clear the 5-second reminder"
   NAME="remind_disable_button"
   onClick="clearTimeout(timerID)">
</FORM>
</BODY>
