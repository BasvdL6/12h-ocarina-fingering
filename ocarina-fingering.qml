// --------------------------------------------
// MuseScore plugin: 12H Ocarina Fingering
// 
// Copyright @ 2024 Bas van der Linden
// 
// 
// --------------------------------------------

import QtQuick 2.2
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0
import Muse.Ui 1.0
import Muse.UiComponents 1.0

MuseScore {
	menuPath: "Plugins.Ocarina Fingering";
	title: "12H Ocarina Fingering";
	version: "2.0";
	description: "Add fingering for 12 hole ocarinas to the score using a dialog box.";
	thumbnailName: "ocarina-fingering.png";
	categoryCode: "composing-arranging-tools";
	requiresScore: true;
	pluginType: "dialog";
	width:  350;
	height: 300;
	
	property var xOrg: 0.65;
	property var yOrg: 3.5;
	
	property var xOff: 0; // text X-Offset
	property var yOff: 0; // text Y-Offset
	property var fPerc: 100; // font size (%)
	property var fScale: 1; // font size (%)
	property var fFace: ""; // font face
	property var iPitch: 0; // instrument's lowest pitch

	onRun: {
		txtSize.currentValue = fPerc;
	}
	
	function addFingerings() {
		class FontObject {
			constructor(name, defaultSize, keyList, extrema = [" ", " "]) {
				this.fontFace = name;
				this.defaultSize = defaultSize;
				this.keyList = keyList;
				this.extrema = extrema
			}
		}
		
		var fonts = [];
		fonts.push(new FontObject(
			"Ocarina TwelveH Alpha",
			20,
			["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U"],
			["Z", "Y"]
		))
		fonts.push(new FontObject(
			"OcarinaT12Custom",
			20,
			["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U"],
			["Z", "Y"]
		))
		fonts.push(new FontObject(
			"Open 12 Hole Ocarina 1",
			20,
			["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U"],
			["Z", "Y"]
		))
		fonts.push(new FontObject(
			"Open 12 Hole Ocarina 2",
			20,
			["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U"],
			["Z", "Y"]
		))
		fonts.push(new FontObject(
			"12 hole taiwanese",
			35,
			["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "A"]
		))
		
		fScale = txtSize.currentValue / 100;
		xOff = txtXoff.currentValue + xOrg;
		yOff = txtYoff.currentValue + yOrg;
		
		var startStaff;
		var endStaff;
		var endTick;
		var fullScore = false;
		
		//find out range to apply to, either selection or full score
		var cursor = curScore.newCursor();
		cursor.rewind(1); //start of selection
		
		if (!cursor.segment) { //no selection
			fullScore  = true;
			startStaff = 0; // start with 1st staff
			endStaff   = curScore.nstaves - 1; // and end with last
		} else {
			startStaff = cursor.staffIdx;
			cursor.rewind(2); //find end of selection
			if (cursor.tick == 0) {
				// this happens when the selection includes the last measure of the score.
				// rewind(2) goes behind the last segment (where there's none) and sets tick=0
				endTick = curScore.lastSegment.tick + 1;
			} else {
				endTick = cursor.tick;
			}
			endStaff = cursor.staffIdx;
		}
		
		var dFont = fonts[txtFont.currentIndex];
		//determine the correct lowest pitch
		var pitches = [45, 40, 50, 47, 43, 42];
		var octaves = 1;
		if (chkTrue.checked) {
			octaves = 3-txtType.currentIndex;
		}
		iPitch = pitches[txtKey.currentIndex] + octaves*12;
		if (!isNaN(txtCust.currentValue)) {
			iPitch += 1*txtCust.currentValue;
		}
		
		curScore.startCmd();
		
		//loop over the selection
		for (var staff = startStaff; staff <= endStaff; staff++) {
			for (var voice = 0; voice < 4; voice++) {
				cursor.rewind(1); // beginning of selection
				cursor.voice    = voice;
				cursor.staffIdx = staff;

				if (fullScore) { // no selection
					cursor.rewind(0); // beginning of score
				}

				while (cursor.segment && (fullScore || cursor.tick < endTick)) {
					if (cursor.element && cursor.element.type == Element.CHORD) {
						var graceChords = cursor.element.graceNotes;
						for (var i = 0; i < graceChords.length; i++) {
							// iterate through all grace chords
							var notes = graceChords[i].notes;
							// there seems to be no way of knowing the exact horizontal pos. of a grace note, so we have to guess:
							cursor.add(noteToText(-2.5 * (graceChords.length - i)+xOff, yOff, notes, dFont));
						}
						var notes = cursor.element.notes;
						cursor.add(noteToText(xOff, yOff, notes, dFont));
					} // end if CHORD
					cursor.next();
				} // end while segment
			} // end for voice
		} // end for staff
		curScore.endCmd();
	}
	
	function noteToText(offsetX, offsetY, notes, fontObj) {
		var text = newElement(Element.STAFF_TEXT);
		text.autoplace = true;
		text.align = 2;//Align.HCenter;
		text.placement = 1;
		text.offsetY = offsetY;
		text.offsetX = offsetX;
		
		text.fontFace = fontObj.fontFace;
		text.fontSize = fontObj.defaultSize * fScale;
		
		addFingerText(notes, text, fontObj);
		return text;
	}
	
	// match note with fingering text
	function addFingerText(notes, text, fontObj) {
		var tuning = fontObj.keyList;
		var lowestPitch = iPitch;
		
		for (var i = 0; i < notes.length; i++) {
			var sep = "\n";
			console.log(notes[i].pitch)
			if (typeof notes[i].pitch === "undefined" || notes[i].tieBack) { // just in case
				return
			}
			if (notes[i].pitch < lowestPitch) {
				text.text = fontObj.extrema[0];
			} else if (notes[i].pitch >= lowestPitch + tuning.length) {
				text.text = fontObj.extrema[1];
			} else if (i == 0) {
				text.text = tuning[notes[i].pitch - lowestPitch];
			} else {
				text.text = tuning[notes[i].pitch - lowestPitch] + sep + text.text;
			}
		}
	}
	
	GridLayout {
		id: winUI

		anchors.fill: parent
		anchors.margins: 5
		columns: 2
		columnSpacing: 10
		rowSpacing: 2
		StyledTextLabel {
			id: lblFont
			text: "Font face"
		}
		StyledDropdown {
			id: txtFont
			currentIndex: 0
			width: 190
			model: [
				{ 'text': "Ocarina TwelveH Alpha" },
				{ 'text': "OcarinaT12Custom" },
				{ 'text': "Open 12 Hole Ocarina 1" },
				{ 'text': "Open 12 Hole Ocarina 2" },
				{ 'text': "12 hole taiwanese" }
			]
			onActivated: function(index, value) {
				currentIndex = index
			}
		}
		StyledTextLabel {
			id: lblSize
			text: "Font scale"
		}
		IncrementalPropertyControl {
			id: txtSize
			decimals: 2
			maxValue: 10000
			minValue: 1
			step: 1
			currentValue: 100
			implicitWidth: 80
			onValueEdited: function(newValue) {
				currentValue = newValue
			}
		}
		StyledTextLabel {
			id: lblXoff
			text: "X-Offset"
		}
		IncrementalPropertyControl {
			id: txtXoff
			decimals: 2
			maxValue: 10
			minValue: -10
			step: 0.5
			currentValue: 0
			implicitWidth: 80
			onValueEdited: function(newValue) {
				currentValue = newValue
			}
		}
		StyledTextLabel {
			id: lblYoff
			text: "Y-Offset"
		}
		IncrementalPropertyControl {
			id: txtYoff
			decimals: 2
			maxValue: 10
			minValue: -10
			step: 0.5
			currentValue: 0
			implicitWidth: 80
			onValueEdited: function(newValue) {
				currentValue = newValue
			}
		}
		StyledTextLabel {
			id: lblType
			text: "Type of ocarina"
		}
		StyledDropdown {
			id: txtType
			currentIndex: 1
			model: [
				{ 'text': "Soprano" },
				{ 'text': "Tenor/alto" },
				{ 'text': "Bass" },
				{ 'text': "Contrabass" }
			]
			onActivated: function(index, value) {
				currentIndex = index
			}
		}
		StyledTextLabel {
			id: lblKey
			text: "Key of ocarina"
		}
		StyledDropdown {
			id: txtKey
			currentIndex: 0
			model: [
				{ 'text': "C" },
				{ 'text': "G" },
				{ 'text': "F" },
				{ 'text': "D" },
				{ 'text': "Bb" },
				{ 'text': "A" }
			]
			onActivated: function(index, value) {
				currentIndex = index
			}
		}
		CheckBox {
			id: chkTrue
			text: 'Use true pitch'
			clip: false
			width: 200
			checked: true
			Layout.columnSpan: 2
			Layout.minimumWidth: 200
			Layout.fillWidth: true
			onClicked: function() {
				checked = !checked
			}
		}
		StyledTextLabel {
			id: lblCust
			text: "Custom transposition"
		}
		IncrementalPropertyControl {
			id: txtCust
			decimals: 0
			maxValue: 12
			minValue: -12
			step: 1
			currentValue: 0
			implicitWidth: 80
			onValueEdited: function(newValue) {
				currentValue = newValue
			}
		}
		FlatButton {
			id: btnApply
			text: "Apply"
			onClicked: addFingerings()
		}
		FlatButton {
			id: btnUndo
			text: "Undo"
			onClicked: {cmd("undo");}
		}

	} // GridLayout
}
