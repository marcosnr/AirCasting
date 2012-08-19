function SessionsMapCtrl($scope, $http, params, heat, $window, map, sensors, expandables, storage, storageEvents) {
  $scope.setDefaults = function() {
    $scope.params = params;
    $scope.storage = storage;
    $scope.storageEvents = storageEvents;
    $scope.sensors = sensors;
    $scope.expandables = expandables;

    _.each(['sensor', 'location', 'usernames'], function(name) {
      $scope.expandables.show(name);
    });

    var locationParams = $scope.params.get('data').location || {};
    $scope.params.update({data: {
      location: {distance: locationParams.distance || "5", limit: locationParams.limit || false},
      heat:  heat.getValues() || heat.parse([0,1,2,3,4])
    }});
  };

  $scope.$watch("sensors.selectedId()", function(newValue, oldValue) {
    $scope.params.update({sessionsIds: [] });
  });

  $scope.$watch("sensors.anySelectedId()", function(newValue, oldValue) {
    if(!newValue){
      return;
    }
    var data = heat.toSensoredList(sensors.anySelected());
    $scope.params.update({data: {heat: heat.parse(data) }});
  });

  $scope.setDefaults();

}
SessionsMapCtrl.$inject = ['$scope', '$http', 'params', 'heat',
  '$window', 'map', 'sensors', 'expandables', 'storage', 'storageEvents'];
