-- TIP: to find all possible translations in the modules directory use the following command
-- find \( -name "*.lua" -o -name "*.otui" \) -exec grep -oE "tr\\('(\\\\'|[^'])*'" {} \; -exec grep -oE "tr\\(\"(\\\\\"|[^\"])*" {} \; | sort | uniq | sed "s/^tr(.\(.*\).$/[\"\1\"] = nil,/"

Locales = { }

-- private variables
local defaultLocaleName = 'en'
local installedLocales
local currentLocale
local localeComboBox

-- private functions
local function sendLocale(localeName)
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(1, localeName)
    return true
  end
  return false
end

local function onLocaleComboBoxOptionChange(self, optionText, optionData)
  if Locales.setLocale(optionData) then
    Settings.set('locale', optionData)
    sendLocale(currentLocale.name)
    reloadModules()
  end
end

-- hooked functions
local function onGameStart()
  sendLocale(currentLocale.name)
end

local function onServerSetLocale(protocol, opcode, buffer)
  local locale = installedLocales[buffer]
  if locale then
    localeComboBox:setCurrentOption(locale.languageName)
  end
end

-- public functions
function Locales.init()
  installedLocales = {}

  Locales.installLocales('locales')

  local userLocaleName = Settings.get('locale', 'false')
  if userLocaleName ~= 'false' and Locales.setLocale(userLocaleName) then
    pdebug('Using configured locale: ' .. userLocaleName)
  else
    pdebug('Using default locale: ' .. defaultLocaleName)
    Locales.setLocale(defaultLocaleName)
    Settings.set('locale', defaultLocaleName)
  end

  addEvent( function()
              localeComboBox = createWidget('ComboBox', rootWidget:recursiveGetChildById('rightButtonsPanel'))
              for key,value in pairs(installedLocales) do
                localeComboBox:addOption(value.languageName, value.name)
              end
              localeComboBox:setCurrentOption(currentLocale.languageName)
              localeComboBox.onOptionChange = onLocaleComboBoxOptionChange
            end, false)

  Extended.register(1, onServerSetLocale)
  connect(g_game, { onGameStart = onGameStart })
end

function Locales.terminate()
  installedLocales = nil
  currentLocale = nil
  localeComboBox = nil
  Extended.unregister(1)
  disconnect(g_game, { onGameStart = onGameStart })
end

function Locales.installLocale(locale)
  if not locale or not locale.name then
    error('Unable to install locale.')
  end

  local installedLocale = installedLocales[locale.name]
  if installedLocale then
    for word,translation in pairs(locale.translation) do
      installedLocale.translation[word] = translation
    end
  else
    installedLocales[locale.name] = locale
    if localeComboBox then
      localeComboBox.onOptionChange = nil
      localeComboBox:addOption(locale.languageName, locale.name)
      localeComboBox.onOptionChange = onLocaleComboBoxOptionChange
    end
  end
end

function Locales.installLocales(directory)
  dofiles(directory)
end

function Locales.setLocale(name)
  local locale = installedLocales[name]
  if not locale then
    pwarning("Locale " .. name .. ' does not exist.')
    return false
  end
  currentLocale = locale
  return true
end

-- global function used to translate texts
function tr(text, ...)
  if currentLocale then
    if tonumber(text) then
      -- todo: use locale information to calculate this. also detect floating numbers
      local out = ''
      local number = tostring(text):reverse()
      for i=1,#number do
        out = out .. number:sub(i, i)
        if i % 3 == 0 and i ~= #number then
          out = out .. ','
        end
      end
      return out:reverse()
    elseif tostring(text) then
      local translation = currentLocale.translation[text]
      if not translation then
        if currentLocale.name ~= defaultLocaleName then
          pwarning('Unable to translate: \"' .. text .. '\"')
        end
        translation = text
      end
      return string.format(translation, ...)
    end
  end
  return text
end
