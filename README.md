# philips-hue-cli

A script to manage information on your Philips Hue hub. You can either enter your Hue hub information into the script or it can pull the information from your Home Assistant configuration if you have added the Hue component. You can manually enter your Hue information by editing the script and adding your Hue hub IP address as hue_url and Hue user name as hue_user. The hue_url should be the IP address only, example 192.168.1.111.

You can see rules saved to your hub as well as make changes to lights, groups, scenes and sensors.

Rules can only be viewed at this time. Rules will either be red, orange, or yellow based on the number of times they have been triggered.

Lights can be renamed, turned on or off, and see the groups they are contained in. When viewing lights the name of the light is orange if it is on. The light description is green if it is a color light and pale yellow if it a temperature color light. The manufacturer is yellow if it is from a third-party manufacturer.

Groups can be renamed and deleted from the hub. You can also create new groups saved to the hub. Group names will be orange if all lights are on and yellow if any of the lights are on. Groups that are also Rooms will be a pale yellow.

Sensors can be renamed and you can view all the sensors on single hardware devices. For example you can see the light sensor, temperature sensor and occupancy sensor from a Hue Motion Sensor at once. Switches are colored according to their type, daylight is pale yellow, temperature is blue, light level is yellow, presence are green, and switches are brown, and generic sensors are grey. The manufacturer is yellow if it is from a third-party manufacturer.

Scenes can be renamed and deleted from the hub. Scenes that are locked due to other settings are colored red. These cannot be renamed or deleted. All scene identifiers are grey.

If a device is unreachable all information will show up in red.
