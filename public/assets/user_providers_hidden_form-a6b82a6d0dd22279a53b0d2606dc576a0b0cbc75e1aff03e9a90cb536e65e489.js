$(document).ready(function() {
	var username = document.getElementsByName("username")[0].value,
	    email = document.getElementsByName("email")[0].value;
	document.getElementById('userEmail').value = email;
	$("#hidden_form").submit();
}); 
