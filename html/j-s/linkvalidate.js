/* Used with JQuery and Validation plugin */


$().ready(function() {
	
	// validate signup form on keyup and submit
	$("#ylinkform").validate({
		rules: {
			url: {
				required: true,
				url: true
			},
			shortname: {
				required: "#is_generated:checked",
				minlength: 4
			},
		},
		messages: {
			url: "<br>Please enter a valid URL",
			shortname: "<br>Please use at least 4 characters"
		}
	});

	
	// hide shortname selection
	var generated = $("#is_generated");
	// shortname is optional, hide at first
	var inital = generated.is(":checked");
	var sn = $("#sn")[inital ? "removeClass" : "addClass"]("hidden");
	var shortnameInput = sn.find("input").attr("disabled", !inital);
	// show when shortname is checked
	generated.click(function() {
		sn[this.checked ? "removeClass" : "addClass"]("hidden");
		shortnameInput.attr("disabled", !this.checked);
	});
});


function setFocus() {
	var loginForm = document.getElementById("ylinkform");
	if (loginForm) {
		loginForm["url"].focus();
	}
}