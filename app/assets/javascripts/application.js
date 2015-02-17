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


var awsEventsApp = angular.module('awsEventsApp', ['ui.bootstrap']);

awsEventsApp.controller('AwsEventListCtrl', function ($scope, $http, $interval) {
	$scope.oneAtATime = true;

	$scope.status = {
    	isFirstOpen: true,
    	isFirstDisabled: false
  	};

  	$scope.items = ['Item 1', 'Item 2', 'Item 3'];

	$http.get('/aws/api-aws-events', { headers: {'Content-Type': 'application/javascript'}})
	.success(function (data) {
		$scope.events = data;
	})

	$interval(function (argument) {
		$http.get('/aws/api-aws-events', { headers: {'Content-Type': 'application/javascript'}})
		.success(function (data) {
			$scope.events = data;
		})
	}, 1000*60);
})

