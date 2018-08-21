/*
The MIT License (MIT)

Copyright (c) 2016 Seth Duda

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

params ["_vehicle", ["_rappelHeight", 25], ["_positionASL", []]];

if ((driver _vehicle) call d_fnc_isplayer) exitWith {};
if (local _vehicle) then {
	_this spawn {
		params ["_vehicle", ["_rappelHeight", 25], ["_positionASL", []]];

		_heliGroup = group driver _vehicle;
		_vehicle setVariable ["AR_Units_Rappelling", true];

		_heliGroupOriginalBehaviour = behaviour leader _heliGroup;
		_heliGroupOriginalCombatMode = combatMode leader _heliGroup;
		_heliGroupOriginalFormation = formation _heliGroup;

		if (_positionASL isEqualTo []) then {
			_positionASL = AGLtoASL [(getPos _vehicle) select 0, (getPos _vehicle) select 1, 0];
		};
		_positionASL = _positionASL vectorAdd [0, 0, _rappelHeight];
		
		_gameLogicLeader = _heliGroup createUnit ["LOGIC", ASLToAGL _positionASL, [], 0, ""];
		_heliGroup selectLeader _gameLogicLeader;

		_heliGroup setBehaviour "Careless";
		_heliGroup setCombatMode "Blue";
		_heliGroup setFormation "File";
		
		// Wait for heli to slow down
		waitUntil {(vectorMagnitude (velocity _vehicle)) < 10 && {_vehicle distance2d _gameLogicLeader < 50}};
		
		// Force heli to specific position
		[_vehicle, _positionASL] spawn {
			params ["_vehicle","_positionASL"];
			
			while { _vehicle getVariable ["AR_Units_Rappelling",false] && alive _vehicle } do {

				_velocityMagatude = 5;
				_distanceToPosition = ((getPosASL _vehicle) distance _positionASL);
				if (_distanceToPosition <= 10) then {
					_velocityMagatude = (_distanceToPosition / 10) * _velocityMagatude;
				};
				
				_currentVelocity = velocity _vehicle;
				_currentVelocity = _currentVelocity vectorAdd (((getPosASL _vehicle) vectorFromTo _positionASL ) vectorMultiply _velocityMagatude);
				_currentVelocity = (vectorNormalized _currentVelocity) vectorMultiply ( (vectorMagnitude _currentVelocity) min _velocityMagatude );
				_vehicle setVelocity _currentVelocity;
				
				sleep 0.05;
			};
		};

		// Find all units that will be rappelling
		_rappelUnits = [];
		_rappelledGroups = [];
		{
			if (alive _x && {group _x != _heliGroup}) then {
				_rappelUnits pushBack _x;
				_rappelledGroups pushBack (group _x);
			};
		} forEach crew _vehicle;

		// Rappel all units
		_unitsOutsideVehicle = [];
		while {count _unitsOutsideVehicle != count _rappelUnits} do { 	
			_distanceToPosition = (getPosASL _vehicle) distance _positionASL;
			if (_distanceToPosition < 3) then {
				{
					[_x, _vehicle] call AR_fnc_Rappel_From_Heli;					
					sleep 1;
				} forEach (_rappelUnits - _unitsOutsideVehicle);
				{
					if !(_x in _vehicle) then {
						_unitsOutsideVehicle pushBack _x;
					};
				} forEach (_rappelUnits - _unitsOutsideVehicle);
			};
			sleep 2;
		};
		
		// Wait for all units to reach ground
		_unitsRappelling = true;
		while {_unitsRappelling} do {
			_unitsRappelling = false;
			{
				if (_x getVariable ["AR_Is_Rappelling", false]) then {
					_unitsRappelling = true;
				};
			} forEach _rappelUnits;
			sleep 3;
		};
		
		deleteVehicle _gameLogicLeader;
		
		_heliGroup setBehaviour _heliGroupOriginalBehaviour;
		_heliGroup setCombatMode _heliGroupOriginalCombatMode;
		_heliGroup setFormation _heliGroupOriginalFormation;

		_vehicle setVariable ["AR_Units_Rappelling",nil];
	};
} else {
	_this remoteExecCall ["AR_fnc_Rappel_All_Cargo", _vehicle];
};
