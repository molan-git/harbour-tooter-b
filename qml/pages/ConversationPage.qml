import QtQuick 2.0
import Sailfish.Silica 1.0
import harbour.tooterb.Uploader 1.0
import "../lib/API.js" as Logic
import "./components/"


Page {
	id: conversationPage

    property string headerTitle: ""
    property string type
    property alias title: header.title
    property alias description: header.description
    property alias avatar: header.image
	property string suggestedUser: ""
	property ListModel suggestedModel
	property string toot_id: ""
    property string toot_url: ""
    property string toot_uri: ""
    property int tootMaxChar: 500;
    property bool bot: false
    property ListModel mdl

	allowedOrientations: Orientation.All
	onSuggestedUserChanged: {
		console.log(suggestedUser)
		suggestedModel = Qt.createQmlObject(
			'import QtQuick 2.0; ListModel {   }',
			Qt.application, 'InternalQmlObject'
		)
		predictionList.visible = false
		if (suggestedUser.length > 0) {
			var msg = {
				"action": 'accounts/search',
				"method": 'GET',
				"model": suggestedModel,
				"mode": "append",
				"params": [{
						"name": "q",
						"data": suggestedUser
					}],
				"conf": Logic.conf
			}
			worker.sendMessage(msg)
			predictionList.visible = true
		}
	}

	ListModel {
		id: mediaModel
		onCountChanged: {
			btnAddImage.enabled = mediaModel.count < 4
		}
	}

	WorkerScript {
		id: worker
		source: "../lib/Worker.js"
		onMessage: {
			console.log(JSON.stringify(messageObject))
		}
	}

	ProfileHeader {
		id: header
		visible: false
	}

    SilicaListView {
        id: myList
		header: PageHeader {
            title: headerTitle // pageTitle pushed from MainPage.qml or VisualContainer.qml
		}
		clip: true
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: if (panel.open == true) {
                            panel.top
                        } else {
                            hiddenPanel.top
                        }
		model: mdl
		section {
			property: 'section'
			delegate: SectionHeader {
				height: Theme.itemSizeExtraSmall
				text: Format.formatDate(section, Formatter.DateMedium)
			}
		}
		delegate: VisualContainer {
		}
		onCountChanged: {
			if (mdl)
				for (var i = 0; i < mdl.count; i++) {
					if (mdl.get(i).status_id === toot_id) {
						console.log(mdl.get(i).status_id)
						positionViewAtIndex(i, ListView.Center)
					}
				}
		}

        PullDownMenu {
            id: pulleyConversation
            visible: type === "reply"
            MenuItem {
                text: qsTr("Copy Link to Clipboard")
                onClicked: if (toot_url === "") {

                               var test = toot_uri.split("/")
                               console.log(toot_uri)
                               console.log(JSON.stringify(test))
                               console.log(JSON.stringify(test.length))
                               if (test.length === 8 && (test[7] === "activity")) {
                                   var urialt = toot_uri.replace("activity", "")
                                   Clipboard.text = urialt
                               }
                               else Clipboard.text = toot_uri

                           } else onClicked: Clipboard.text = toot_url
            }
        }
    }

	Rectangle {
		id: predictionList
		visible: false
        color: Theme.highlightDimmerColor
        height: parent.height - panel.height - (Theme.paddingLarge * 4.5)
        anchors {
            left: panel.left
            right: panel.right
            bottom: if (panel.open == true) {
                        panel.top
                    } else {
                        hiddenPanel.top
                    }
        }

        SilicaListView {
            rotation: 180
            anchors.fill: parent
			model: suggestedModel
			clip: true
            quickScroll: false
            VerticalScrollDecorator {}
			delegate: ItemUser {
                rotation: 180
				onClicked: {
					var start = toot.cursorPosition
					while (toot.text[start] !== "@" && start > 0) {
						start--
					}
					textOperations.text = toot.text
					textOperations.cursorPosition = toot.cursorPosition
					textOperations.moveCursorSelection(start - 1, TextInput.SelectWords)
					toot.text = textOperations.text.substring(0, textOperations.selectionStart)
						+ ' @'
						+ model.account_acct
						+ ' '
						+ textOperations.text.substring(textOperations.selectionEnd).trim()

					toot.cursorPosition = toot.text.indexOf('@' + model.account_acct)
				}
			}
			onCountChanged: {
                positionViewAtBeginning(suggestedModel.count - 1, ListView.Beginning)
			}
		}
	}

	DockedPanel {
		id: panel
		width: parent.width
        height: progressBar.height + toot.height + (mediaModel.count ? uploadedImages.height : 0)
			+ btnContentWarning.height + Theme.paddingMedium
            + (warningContent.visible ? warningContent.height : 0)
        dock: Dock.Bottom
        open: true
        animationDuration: 200

        Rectangle {
			width: parent.width
			height: progressBar.height
			color: Theme.highlightBackgroundColor
			opacity: 0.2
			anchors {
				left: parent.left
				right: parent.right
				top: parent.top
			}
		}

		Rectangle {
			id: progressBar
			width: toot.text.length ? panel.width * (toot.text.length / tootMaxChar) : 0
            height: Theme.itemSizeSmall * 0.05
			color: Theme.highlightBackgroundColor
			opacity: 0.7
			anchors {
				left: parent.left
                top: parent.top
			}
		}

		TextField {
			id: warningContent
			visible: false
			height: visible ? implicitHeight : 0
			anchors {
                top: parent.top
				topMargin: Theme.paddingMedium
				left: parent.left
				right: parent.right
			}
			autoScrollEnabled: true
			labelVisible: false
            font.pixelSize: Theme.fontSizeSmall
            placeholderText: qsTr("Write your warning here")
            placeholderColor: palette.highlightColor
            color: palette.highlightColor
			horizontalAlignment: Text.AlignLeft
			EnterKey.onClicked: {}
		}

		TextInput {
			id: textOperations
			visible: false
		}

		TextArea {
			id: toot
			anchors {
				top: warningContent.bottom
				topMargin: Theme.paddingMedium
				left: parent.left
                right: parent.right
                rightMargin: Theme.paddingLarge * 2
			}
			autoScrollEnabled: true
			labelVisible: false
            text: description !== "" && (description.charAt(0) === '@'
																	 || description.charAt(
                                                                         0) === '#') ? description + ' ' : ''
            height: if (type !== "reply") {
                        Math.max(conversationPage.height / 3, Math.min(conversationPage.height * 0.65, implicitHeight))
                    }
                    else {
                        Math.max(conversationPage.height / 4, Math.min(conversationPage.height * 0.65, implicitHeight))
                    }
            horizontalAlignment: Text.AlignLeft
            placeholderText: qsTr("What's on your mind?")
            font.pixelSize: Theme.fontSizeSmall
            EnterKey.onClicked: {}
			onTextChanged: {
				textOperations.text = toot.text
				textOperations.cursorPosition = toot.cursorPosition
				textOperations.selectWord()
				textOperations.select(
							textOperations.selectionStart ? textOperations.selectionStart - 1 : 0,
							textOperations.selectionEnd)
				//console.log(textOperations.text.substr(textOperations.selectionStart, textOperations.selectionEnd))
				console.log(toot.text.length)
				suggestedUser = ""
				if (textOperations.selectedText.charAt(0) === "@") {
					suggestedUser = textOperations.selectedText.trim().substring(1)
				}
			}
		}

		IconButton {
			id: btnSmileys

            property string selection

            opacity: 0.7
            icon {
                color: Theme.secondaryColor
                width: Theme.iconSizeSmallPlus
                fillMode: Image.PreserveAspectFit
                source: "../../qml/images/icon-m-emoji.svg"
            }
			anchors {
                top: warningContent.bottom
				bottom: bottom.top
				right: parent.right
				rightMargin: Theme.paddingSmall
			}
            onSelectionChanged: { console.log(selection) }
            onClicked: pageStack.push(emojiSelect)
		}

		SilicaGridView {
			id: uploadedImages
			width: parent.width
            anchors.top: bottom.toot
			anchors.bottom: parent.bottom
            height: mediaModel.count ? Theme.itemSizeExtraLarge : 0
            model: mediaModel
			cellWidth: uploadedImages.width / 4
            cellHeight: Theme.itemSizeExtraLarge
			delegate: BackgroundItem {
				id: myDelegate
				width: uploadedImages.cellWidth
				height: uploadedImages.cellHeight
				RemorseItem {
                    id: remorse
				}

				Image {
					anchors.fill: parent
					fillMode: Image.PreserveAspectCrop
					source: model.preview_url
				}
				onClicked: {
					var idx = index
					console.log(idx)
					//mediaModel.remove(idx)
					remorse.execute(myDelegate, qsTr("Delete"), function () {
						mediaModel.remove(idx)
					})
				}
			}
			add: Transition {
				NumberAnimation {
					property: "opacity"
					from: 0
					to: 1.0
					duration: 800
				}
			}
			remove: Transition {
				NumberAnimation {
					property: "opacity"
					from: 1.0
					to: 0
					duration: 800
				}
			}
			displaced: Transition {
				NumberAnimation {
					properties: "x,y"
					duration: 800
					easing.type: Easing.InOutBack
				}
			}
		}

		IconButton {
			id: btnContentWarning
			anchors {
                top: toot.bottom
                topMargin: -Theme.paddingSmall * 1.5
				left: parent.left
				leftMargin: Theme.paddingMedium
			}
			icon.source: "image://theme/icon-s-warning?"
				+ (pressed ? Theme.highlightColor : (warningContent.visible ? Theme.secondaryHighlightColor : Theme.primaryColor))
			onClicked: warningContent.visible = !warningContent.visible
		}

		IconButton {
			id: btnAddImage
			enabled: mediaModel.count < 4
			anchors {
                top: toot.bottom
                topMargin: -Theme.paddingSmall * 1.5
				left: btnContentWarning.right
				leftMargin: Theme.paddingSmall
			}
			icon.source: "image://theme/icon-s-attach?"
				+ (pressed ? Theme.highlightColor : (warningContent.visible ? Theme.secondaryHighlightColor : Theme.primaryColor))
			onClicked: {
				btnAddImage.enabled = false
				var once = true
				var imagePicker = pageStack.push("Sailfish.Pickers.ImagePickerPage", {"allowedOrientations": Orientation.All})
				imagePicker.selectedContentChanged.connect(function () {
					var imagePath = imagePicker.selectedContent
					console.log(imagePath)
					imageUploader.setUploadUrl(Logic.conf.instance + "/api/v1/media")
					imageUploader.setFile(imagePath)
					imageUploader.setAuthorizationHeader(Logic.conf.api_user_token)
					imageUploader.upload()
				})
			}
		}

		ImageUploader {
			id: imageUploader
			onProgressChanged: {
				console.log("progress " + progress)
				uploadProgress.width = parent.width * progress
			}
			onSuccess: {
				uploadProgress.width = 0
				console.log(replyData)
				mediaModel.append(JSON.parse(replyData))
			}
			onFailure: {
				uploadProgress.width = 0
				btnAddImage.enabled = true
				console.log(status)
				console.log(statusText)
			}
		}

		ComboBox {
            id: privacy
			anchors {
                top: toot.bottom
                topMargin: -Theme.paddingSmall * 1.5
				left: btnAddImage.right
                right: btnSend.left
            }
            menu: ContextMenu {
				MenuItem {
                    text: qsTr("Public")
				}
				MenuItem {
                    text: qsTr("Unlisted")
				}
				MenuItem {
                    text: qsTr("Followers-only")
				}
				MenuItem {
                    text: qsTr("Direct")
				}
			}
		}

		IconButton {
			id: btnSend
			icon.source: "image://theme/icon-m-send?"
				+ (pressed ? Theme.highlightColor : Theme.primaryColor)
			anchors {
                top: toot.bottom
                topMargin: -Theme.paddingSmall * 1.5
				right: parent.right
                rightMargin: Theme.paddingSmall
			}
			enabled: toot.text !== "" && toot.text.length < tootMaxChar && uploadProgress.width == 0
			onClicked: {
                var visibility = ["public", "unlisted", "private", "direct"]
				var media_ids = []
				for (var k = 0; k < mediaModel.count; k++) {
					console.log(mediaModel.get(k).id)
					media_ids.push(mediaModel.get(k).id)
				}
				var msg = {
					"action": 'statuses',
					"method": 'POST',
					"model": mdl,
					"mode": "append",
					"params": {
						"status": toot.text,
						"visibility": visibility[privacy.currentIndex],
						"media_ids": media_ids
					},
					"conf": Logic.conf
				}
				if (toot_id)
					msg.params['in_reply_to_id'] = (toot_id) + ""

				if (warningContent.visible && warningContent.text.length > 0) {
					msg.params['sensitive'] = 1
					msg.params['spoiler_text'] = warningContent.text
				}

                worker.sendMessage(msg)
                warningContent.text = ""
                toot.text = ""
                mediaModel.clear()
                sentBanner.showText(qsTr("Toot sent!"))
			}
		}

		Rectangle {
			id: uploadProgress
			color: Theme.highlightBackgroundColor
            anchors.bottom: parent.bottom
			anchors.left: parent.left
            height: Theme.itemSizeSmall * 0.05
		}
	}

	Component.onCompleted: {
		toot.cursorPosition = toot.text.length
		if (mdl.count > 0) {
			var setIndex = 0
			switch (mdl.get(0).status_visibility) {
			case "unlisted":
				setIndex = 1
				break
			case "private":
				setIndex = 2
				break
			case "direct":
				privacy.enabled = false
				setIndex = 3
				break
			default:
				privacy.enabled = true
				setIndex = 0
			}
			privacy.currentIndex = setIndex
		}

		console.log(JSON.stringify())

		worker.sendMessage({
			"action": 'statuses/' + mdl.get(0).status_id + '/context',
			"method": 'GET',
			"model": mdl,
			"params": { },
			"conf": Logic.conf
		})
	}

    BackgroundItem {
        id: hiddenPanel
        visible: !panel.open
        height: Theme.paddingLarge * 0.5
        width: parent.width
        opacity: enabled ? 0.6 : 0.0
        Behavior on opacity { FadeAnimator { duration: 400 } }
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.open = !panel.open
        }

        Rectangle {
            id: hiddenPanelBackground
            width: parent.width
            height: parent.height
            color: Theme.highlightBackgroundColor
            opacity: 0.4
            anchors.fill: parent
        }

        Rectangle {
            id: progressBarBackground
            width: parent.width
            height: progressBarHiddenPanel.height
            color: Theme.highlightBackgroundColor
            opacity: 0.2
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
        }

        Rectangle {
            id: progressBarHiddenPanel
            width: toot.text.length ? panel.width * (toot.text.length / tootMaxChar) : 0
            height: Theme.itemSizeSmall * 0.05
            color: Theme.highlightBackgroundColor
            opacity: 0.7
            anchors {
                left: parent.left
                top: parent.top
            }
        }

    }

    EmojiSelect {
        id: emojiSelect
	}

    InfoBanner {
        id: sentBanner
    }

}
