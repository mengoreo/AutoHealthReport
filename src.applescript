-- properties
use scripting additions
use framework "Foundation"

global filePath, theURL, rememberPasswordChecked, successInfo, errorInfo, tipBody, notificationBody

set filePath to (POSIX path of (path to documents folder) as text) & "autoReport.plist" as text
set rememberPasswordChecked to false
set tipBody to {prefix:"", filePath:"", suffix:""}
set notificationBody to {title:"", body:""}
set theURL to ""

-- variables
global allowButtonText, okBtnText, browser, screenResolution, reloadButtonText, checkBoxText, lastPosition, FIRSTTIMETOREPORT, REPORTEDYESTODAY, REPORTEDTODAY
set FIRSTTIMETOREPORT to -1
set REPORTEDYESTODAY to 0
set REPORTEDTODAY to 1

go()
-- functions
on openSettings()
	tell application "System Preferences"
		activate
		
		set revealed to false
		repeat until revealed
			try
				set the current pane to pane id "com.apple.preference.security"
				set revealed to true
			end try
		end repeat
		
		try
			reveal anchor "Privacy_Accessibility" of current pane
		on error
			set notificationBody to {body:"尝试打开辅助功能页失败，请自行打开"} & notificationBody
			
			display notification notificationBody's body with title notificationBody's title sound name "Blow"
		end try
	end tell
	activate current application
end openSettings

on closeSettings()
	tell application "System Preferences" to quit
	activate current application
end closeSettings

on confirmedTips()
	try
		try
			if (read ("used")) is equal to "" then
				-- updated
				return true
			end if
		on error
			-- try lastTime Opened
			if (read ("lastTimeOpened")) > 0 then -- throw if not there which means first time
				return true
			end if
		end try
		-- need to update
		openSettings()
		set theResponse to display dialog "请将上一版本从「系统偏好设置->安全性与隐私->隐私->辅助功能」的应用列表中移除，并将此版本添加到应用列表，以使用辅助功能🧏🏻" with icon note buttons {"我用旧的就可以", "好了"} default button "我用旧的就可以"
		closeSettings()
		
		
		if (button returned of theResponse) is "好了" then
			save {"used", ""}
			save {"lastTimeOpened", getSecondsFrom1970()}
			
			aboutToShowTips() -- for update
			return true
		else
			return false
		end if
	on error the errorMsg
		-- 这里也可以根据是否存在文件判断，太麻烦了，就这样吧
		log errorMsg
		-- realy the first time
		openSettings()
		set theResponse to display dialog "请将本君加入到「系统偏好设置->安全性与隐私->隐私->辅助功能」的应用列表中，要不然我就不给你用了🧏🏻" with icon note buttons {"去你的", "好了"} default button "去你的"
		
		closeSettings()
		if (button returned of theResponse) is "好了" then
			set theResult to display dialog "还有！本君在开始为你打卡前需要关闭 Safari 所有窗口，你确认所有工作都保存了?" with icon stop buttons {"我不想用了", "知道了"} default button "知道了"
			if (button returned of theResult) is "知道了" then
				return true
			else
				return false
			end if
		else
			return false
		end if
	end try
end confirmedTips

on aboutToShowTips()
	set notificationBody to {body:tipBody's prefix & filePath & tipBody's suffix} & notificationBody
end aboutToShowTips

on validURL()
	try
		set theURL to (read ("theURL"))
	on error
		set theResponse to display dialog "你的健康打卡地址？" default answer "" with icon note buttons {"不干了", "冲"} default button "冲"
		if (button returned of theResponse) is "冲" then
			save {"theURL", text returned of theResponse}
			set theURL to (read ("theURL"))
			if theURL is equal to "" then
				return validURL()
			end if
			
			
			aboutToShowTips() -- for first time use
			return true
		else
			return false
		end if
	end try
	
	return true
end validURL

to getSecondsFrom1970()
	return ((current application's NSDate's |date|()'s timeIntervalSince1970()) - 1.26144E+9) as integer
end getSecondsFrom1970

on reported()
	try
		set lastModifiedDate to (read ("lastTimeOpened"))
		set currentDay to getSecondsFrom1970()
		if lastModifiedDate > currentDay - 400 then
			-- probably opened from notificaiton
			return true
		end if
		
		--if lastModifiedDate > currentDay - 86400 then
		--	return REPORTEDTODAY -- not implemented
		--end if
		
	on error -- first time
		return false
		-- return FIRSTTIMETOREPORT -- not implemented
	end try
	return false
	-- return REPORTEDYESTODAY -- not implemented
end reported


on read (theKey)
	tell application "System Events"
		tell property list file filePath
			log (value of property list item theKey)
			return value of property list item theKey
		end tell
	end tell
end read


to save {theKey, theValue}
	tell application "System Events"
		try
			tell property list file filePath
				set value of property list item theKey to theValue
			end tell
		on error -- no property or file
			try
				tell property list items of property list file filePath
					make new property list item at end with properties {kind:class of theValue, name:theKey, value:theValue}
				end tell
			on error -- no file
				set plistParentRecord to make new property list item with properties {kind:record} as record
				
				set propertyListFile to make new property list file with properties {contents:plistParentRecord, name:filePath}
				
				tell property list items of property list file filePath
					make new property list item at end with properties {kind:class of theValue, name:theKey, value:theValue}
				end tell
			end try
		end try
	end tell
end save


to unCheckUsernamePassword()
	tell application "Safari" to activate
	repeat until application "Safari" is running
	end repeat
	
	tell application "System Events" to tell application process "Safari"
		set frontmost to true
		keystroke "," using {command down}
		with timeout of 3 seconds
			set boxAppeared to false
			repeat until boxAppeared
				try
					set tb to toolbar 1 of window 1
					set buttonName to (name of button 3 of tb as string)
					click button 3 of tb
					
					set form to group 1 of group 1 of window 1
					
					set theCheckbox to checkbox 3 of form -- disable auto fill user name password(in case additional sheet appears)
					
					set boxAppeared to true
				end try
			end repeat
		end timeout --XXXX
		
		
		
		tell theCheckbox
			if (its value as boolean) is not equal to rememberPasswordChecked then -- checked
				click theCheckbox
				set rememberPasswordChecked to true
			end if
		end tell
		
		-- close window
		keystroke "w" using {command down}
		
	end tell
end unCheckUsernamePassword

to reCheckUsernamePassword()
	if not rememberPasswordChecked then return
	
	tell application "System Events" to tell application process "Safari"
		set frontmost to true
		keystroke "," using {command down}
		set tb to toolbar 1 of window 1
		set buttonName to (name of button 3 of tb as string)
		click button 3 of tb
		
		set form to group 1 of group 1 of window 1
		
		set theCheckbox to checkbox 3 of form -- disable auto fill user name password(in case additional sheet appears)
		
		tell theCheckbox
			click theCheckbox
		end tell
		
		-- close window
		keystroke "w" using {command down}
		
	end tell
end reCheckUsernamePassword


to ready()
	
	if reported() then
		return false
	end if
	
	if not confirmedTips() or not validURL() then
		return false
	end if
	
	set allowed to false
	repeat until allowed
		try
			unCheckUsernamePassword()
			set allowed to true
			closeSettings()
		on error
			openSettings()
			set theResponse to display dialog "权限貌似出了问题，请确认允许本君使用辅助功能🧏🏻" with icon note buttons {"不想用了", "好了"} default button "好了"
			if (button returned of theResponse) is "不想用了" then
				return false
			end if
		end try
	end repeat
	
	activate current application
	set browserOpend to false
	try
		get window 1 of application browser
		set browserOpend to true
	end try
	
	if browserOpend then
		tell application browser to close every window
	end if
	
	
	set screenWidth to item 3 of screenResolution
	set screenHeight to item 4 of screenResolution
	
	tell application browser
		open location theURL
		activate
		-- 登录了吗
		try
			repeat until (name of window 1 is equal to "每日上报")
			end repeat
		on error
			return false
		end try
	end tell
	
	-- 调整窗口 防止误点击
	tell application "System Events" to tell the application process "Safari" -- the browser didn't work
		set frontmost to true
		set lastPosition to position of window 1
		set position of window 1 to {screenWidth - 10, screenHeight - 10}
	end tell
	
	return true
end ready

to doneAndClose(flag)
	-- 恢复窗口到合适位置
	tell application "System Events" to tell the application process "Safari"
		activate
		set position of window 1 to {item 1 of lastPosition, item 2 of lastPosition}
	end tell
	reCheckUsernamePassword()
	if flag then
		tell application browser to close every window
	end if
end doneAndClose


to finishLoading()
	-- check if finished loading
	tell application "System Events" to tell application process "Safari"
		set realoadButtonFound to false
		repeat until realoadButtonFound
			try
				repeat with gp in every group of toolbar 1 of window 1
					set btns to name of every button of gp
					if reloadButtonText is in btns then
						set realoadButtonFound to true
					end if
					-- set realoadButtonFound to true
					-- log btns
				end repeat
			end try
		end repeat
	end tell
	
	return true
end finishLoading

to checkAllowButton()
	tell application "System Events"
		tell application process "Safari"
			set frontmost to true
			set tryCounter to 0
			set theSheet to 0
			repeat until tryCounter is equal to 10 -- 超过十次说明已经获取位置权限
				try
					set theSheet to sheet 1 of window 1
					if theSheet is not 0 then
						-- remember
						set theCheckbox to checkbox checkBoxText of theSheet
						tell theCheckbox
							if not (its value as boolean) then click theCheckbox
						end tell
						
						set btns to name of every button of theSheet
						if allowButtonText is in btns then
							-- only one
							-- click button "Allow" of theSheet
							click button allowButtonText of theSheet
							return true -- just allowed
							set tryCounter to 9
						end if
					end if
				end try
				set tryCounter to tryCounter + 1
			end repeat
		end tell
		-- 如果之前没允许浏览器获取位置，会跳出弹窗（暂时还捕捉不到。。）
	end tell
	return false -- already allowed
end checkAllowButton

to startedAllright()
	tell application "Safari" -- need to identified as Safari? `browser` variable error
		-- 地理位置
		-- frist try
		-- repeat until (do JavaScript "document.getElementsByName('area')[0].getElementsByTagName('input')[0].value.length" in document 1) > 0
		do JavaScript "document.getElementsByName('area')[0].click();" in document 1
		--end repeat
	end tell
	
	
	
	if checkAllowButton() is true then -- in case unsuccessful
		-- retry
		tell application "Safari"
			-- 确定按钮		
			if (do JavaScript "return document.getElementsByClassName('wapat-title').length;" in document 1) > 0 then
				do JavaScript "document.getElementsByClassName('wapat-btn wapat-btn-ok')[0].click();" in document 1
			end if
			
			repeat until (do JavaScript "document.getElementsByName('area')[0].getElementsByTagName('input')[0].value.length" in document 1) > 0
				do JavaScript "document.getElementsByName('area')[0].click();" in document 1
			end repeat
		end tell
	end if
	
	delay 3
	tell application "Safari"
		try
			if (do JavaScript "document.getElementsByClassName('wapat-title').length" in document 1) > 0 then
				do JavaScript "document.getElementsByClassName('wapat-btn wapat-btn-ok')[0].click();" in document 1
				set theResult to display dialog "无法获取位置，自己干吧!🤷🏻"
				return false
			else
				-- 是否在校
				do JavaScript "document.getElementsByName('sfzx')[0].getElementsByTagName('div')[2].click();" in document 1
				
				-- 是否已经申领校区所在地健康码				
				do JavaScript "document.getElementsByName('sfsqhzjkk')[0].getElementsByTagName('div')[1].click();" in document 1
				
				-- 今日申领校区所在地健康码的颜色
				do JavaScript "document.getElementsByName('sqhzjkkys')[0].getElementsByTagName('div')[1].click();" in document 1
				
				-- 家庭成员
				do JavaScript "document.getElementsByName('sfymqjczrj')[0].getElementsByTagName('div')[2].click();" in document 1
				
				-- 本人承诺
				do JavaScript "document.getElementsByName('sfqrxxss')[0].getElementsByTagName('div')[1].click();" in document 1
				
				-- 提交信息
				do JavaScript "document.getElementsByClassName('footers')[0].getElementsByTagName('a')[0].click();" in document 1
				
				-- wait dialog shows
				delay 2
				-- 确定
				do JavaScript "document.getElementsByClassName('wapcf-btn wapcf-btn-ok')[0].click();" in document 1
				
				delay 1
				-- ok
				do JavaScript "document.getElementsByClassName('alert')[0].getElementsByTagName('a')[0].click();" in document 1
			end if
		on error -- unknown error ?
			set theResult to display dialog "无法获取位置，自己干吧!🤷🏻"
			return false
		end try
	end tell
	return true
end startedAllright
-- start to report
to go()
	
	-- prepare
	set allowButtonText to ""
	set okBtnText to ""
	set browser to "Safari"
	
	set la to user locale of (get system info)
	log la
	if la starts with "zh" then
		set allowButtonText to "允许"
		set reloadButtonText to "重新载入此页面" -- 繁体慎用
		set checkBoxText to "在一天内记住我的决定"
		set okBtnText to "好"
		set successInfo to "已成功打卡"
		set errorInfo to "打卡失败，点击重新打卡"
		set tipBody to {prefix:"应用数据保存在了 ", suffix:"
你可以随时更改。但请注意使用正确打卡地址。"} & tipBody
		set notificationBody to {title:"自动打卡提示"} & notificationBody
	else -- if la starts with "en" then
		set allowButtonText to "Allow"
		set reloadButtonText to "Reload this page"
		set checkBoxText to "Remember my decision for one day"
		set okBtnText to "OK"
		set successInfo to "Succeeded"
		set errorInfo to "Auto Report Failed. Click To Restart."
		set tipBody to {prefix:"App data saved to ", suffix:"
You can modify it anytime. But careful with the url."} & tipBody
		set notificationBody to {title:"Auto Report Info"} & notificationBody
	end if
	
	tell application "Finder"
		set screenResolution to bounds of window of desktop
	end tell
	
	
	if not ready() then
		return
	end if
	
	-- display tip once
	if notificationBody's body is not equal to "" then
		display notification notificationBody's body with title notificationBody's title sound name "Blow"
	end if
	
	if finishLoading() and startedAllright() then
		doneAndClose(true)
		set notificationBody to {body:successInfo} & notificationBody
	else
		doneAndClose(false)
		set notificationBody to {body:errorInfo} & notificationBody
	end if
	
	display notification notificationBody's body with title notificationBody's title sound name "Blow"
	
	-- succeeded
	save {"lastTimeOpened", getSecondsFrom1970()}
end go