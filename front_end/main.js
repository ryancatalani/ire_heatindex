$(function(){

	$.getJSON('http://rcpublic.s3.amazonaws.com/ire_heatindex/results.json', function(data) {
		console.log(data);

		var display_text = data.display_text;
		$('#display_text').text(display_text);
	});

	function decToTemp(dec) {
		// take square root of value (between 0...1)
		// multiply by 100
		// use celsius to fahrenheit formula
		// round
		return Math.round((Math.sqrt(dec) * 100) * 1.8 + 32);
	}

});