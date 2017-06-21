$(function(){

	$.getJSON('http://rcpublic.s3.amazonaws.com/ire_heatindex/results.json', function(data) {
		console.log(data);

		var display_text = data.display_text;
		$('#display_text').html(display_text);


		var trendChartValues = [];
		for (var i = 0; i < data.results.length; i++) {
			var value = data.results[i].result * 100;
			trendChartValues.push(value);
		};

		var trendCtx = document.getElementById("trend_chart").getContext('2d');
		var trendChart = new Chart(trendCtx, {
			type: 'line',
			data: {
				labels: data.labels,
				datasets: [{
					label: '% of #IRE17 tweets mentioning the weather',
					data: trendChartValues
				}]
			}
		});
	});

	function decToTemp(dec) {
		// take square root of value (between 0...1)
		// multiply by 100
		// use celsius to fahrenheit formula
		// round
		return Math.round((Math.sqrt(dec) * 100) * 1.8 + 32);
	}

});