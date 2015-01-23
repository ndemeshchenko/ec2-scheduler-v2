//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .

$(document).ready(function(){
	$("div.alert").click(function(event) {
		event.preventDefault();
		$(this).hide('slow');
	})	
});


