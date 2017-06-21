$(function(){

	$.getJSON('http://rcpublic.s3.amazonaws.com/ire_heatindex/results.json', function(data) {
		console.log(data);

		var display_text = data.display_text;
		$('#display_text').html(display_text);

		var latest_results = data.results[data.results.length - 1];
		var latest_percent = Math.round(latest_results.result * 100);
		$('#latest_percent').text(latest_percent);


		var trendChartValues = [];
		for (var i = 0; i < data.results.length; i++) {
			var value = Math.round(data.results[i].result * 100);
			trendChartValues.push(value);
		};

		var trendCtx = document.getElementById("trend_chart").getContext('2d');
		var trendChart = new Chart(trendCtx, {
			type: 'line',
			data: {
				labels: data.labels,
				datasets: [{
					label: '% of #IRE17 tweets mentioning the weather',
					data: trendChartValues,
					borderColor: '#fff',
					fill: false,
					pointBorderColor: '#fff',
					pointBackgroundColor: '#fff'
				}]
			},
			options: {
				scales: {
					xAxes: [{
						gridLines: {
							color: 'rgba(255,255,255,0.25)',
							zeroLineColor: 'rgba(255,255,255,0.5)'
						},
						ticks: {
							fontColor: '#fff',
							fontFamily: "'Source Sans Pro', sans-serif"
						}
					}],
					yAxes: [{
						gridLines: {
							color: 'rgba(255,255,255,0.25)',
							zeroLineColor: 'rgba(255,255,255,0.5)'
						},
						ticks: {
							fontColor: '#fff',
							fontFamily: "'Source Sans Pro', sans-serif"
						}
					}]
				},
				legend: {
					display: false
				}
			}
		});
	});

	$('#show_how').click(function(e) {
		e.preventDefault();
		$('#how').slideToggle();
		return false;
	});

	function decToTemp(dec) {
		// take square root of value (between 0...1)
		// multiply by 100
		// use celsius to fahrenheit formula
		// round
		return Math.round((Math.sqrt(dec) * 100) * 1.8 + 32);
	}

});