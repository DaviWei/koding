class AdminModal extends KDModalViewWithForms

  constructor : (options = {}, data) ->

    options =
      title                   : "Admin Panel"
      content                 : "<div class='modalformline'>With great power comes great responsibility. ~ Stan Lee</div>"
      overlay                 : yes
      width                   : 500
      height                  : "auto"
      cssClass                : "admin-kdmodal"
      tabs                    :
        navigable             : yes
        forms                 :
          "User Flags"        :
            buttons           :
              Update          :
                title         : "Update"
                style         : "modal-clean-gray"
                loader        :
                  color       : "#444444"
                  diameter    : 12
                callback      : => @modalTabs.forms["User Flags"].emit "UpdateFlagsClicked"
            fields            :
              Username        :
                label         : "Username:"
                type          : "hidden"
                name          : "username"
                nextElement   :
                  userWrapper :
                    itemClass : KDView
                    cssClass  : "completed-items"
              Flags           :
                label         : "Flags:"
                name          : "flags"
                placeholder   : "no flags assigned"
              Impersonate     :
                label         : "Switch to User"
                itemClass     : KDButtonView
                title         : "Impersonate"
                callback      : =>
                  modal = new KDModalView
                    title          : "Switch to this user?"
                    content        : "<div class='modalformline'>This action will reload Koding and log you in with this user.</div>"
                    height         : "auto"
                    overlay        : yes
                    buttons        :
                      Impersonate  :
                        style      : "modal-clean-green"
                        loader     :
                          color    : "#FFF"
                          diameter : 16
                        callback   : =>
                          accounts = @userController.getSelectedItemData()
                          unless accounts.length is 0
                            KD.impersonate accounts[0].profile.nickname, =>
                              modal.destroy()
                          else
                            modal.destroy()

          "Migrate Kodingen Users" :
            buttons           :
              Migrate         :
                title         : "Migrate"
                style         : "modal-clean-gray"
                loader        :
                  color       : "#444444"
                  diameter    : 12
                callback      : =>
                  form = @modalTabs.forms["Migrate Kodingen Users"]
                  form.inputs.statusInfo.updatePartial 'Working on it...'
                  KD.remote.api.JOldUser.__migrateKodingenUsers
                    limit     : parseInt form.inputs.Count.getValue(), 10
                    delay     : parseInt form.inputs.Delay.getValue(), 10
                  , (err, res)->
                    form.buttons.Migrate.hideLoader()
                    form.inputs.statusInfo.updatePartial res
                    console.log res, err
              Stop            :
                title         : "Stop"
                style         : "modal-clean-red"
                loader        :
                  color       : "#444444"
                  diameter    : 12
                callback      : =>
                  form = @modalTabs.forms["Migrate Kodingen Users"]
                  form.inputs.statusInfo.updatePartial 'Trying to stop...'
                  KD.remote.api.JOldUser.__stopMigrate (err, res)->
                    form.buttons.Stop.hideLoader()
                    form.buttons.Migrate.hideLoader()
                    form.inputs.statusInfo.updatePartial res
                    console.log res, err
            fields            :
              Information     :
                label         : "Current state:"
                type          : "hidden"
                name          : "information"
                nextElement   :
                  currentState:
                    itemClass : KDView
                    partial   : 'Loading...'
                    cssClass  : 'information-line'
              Count           :
                label         : "Number of users to Migrate:"
                type          : "text"
                name          : "nofusers"
                defaultValue  : 10
                placeholder   : "how many users do you want to Migrate?"
                validate      :
                  rules       :
                    regExp    : /\d+/i
                  messages    :
                    regExp    : "numbers only please"
              Delay           :
                label         : "Delay between migrates (in sec.):"
                type          : "text"
                name          : "delay"
                defaultValue  : 60
                placeholder   : "how many seconds do you need before create new user?"
                validate      :
                  rules       :
                    regExp    : /\d+/i
                  messages    :
                    regExp    : "numbers only please"
              Status          :
                label         : "Server output:"
                name          : "status"
                type          : "hidden"
                nextElement   :
                  statusInfo  :
                    itemClass : KDView
                    partial   : '...'
                    cssClass  : 'information-line'

    super options, data

    flagsForm = @modalTabs.forms["User Flags"]
    toField = flagsForm.fields.Username
    userControllerWrapper = flagsForm.fields.userWrapper

    userController = new KDAutoCompleteController
      name                : "userController"
      itemClass           : MemberAutoCompleteItemView
      selectedItemClass   : MemberAutoCompletedItemView
      outputWrapper       : userControllerWrapper
      form                : flagsForm
      itemDataPath        : "profile.nickname"
      listWrapperCssClass : "users"
      submitValuesAsText  : yes
      dataSource          : (args, callback)->
        {inputValue} = args
        blacklist = (data.getId() for data in userController.getSelectedItemData())
        KD.remote.api.JAccount.byRelevance inputValue, {blacklist}, (err, accounts)->
          callback accounts

    toField.addSubView userRequestLineEdit = userController.getView()

    userController.on "ItemListChanged", ->
      accounts = userController.getSelectedItemData()
      if accounts.length > 0
        account = accounts[0]
        flagsForm.inputs.Flags.setValue account.globalFlags?.join(',')
        userRequestLineEdit.hide()
      else
        userRequestLineEdit.show()
        flagsForm.inputs.Flags.setValue ''

    @modalTabs.forms["User Flags"].on "UpdateFlagsClicked", ->
      accounts = userController.getSelectedItemData()
      if accounts.length > 0
        account  = accounts[0]
        flags    = [flag.trim() for flag in flagsForm.inputs.Flags.getValue().split(",")][0]
        account.updateFlags flags, (err)->
          error err if err
          flagsForm.buttons.Update.hideLoader()

      else
        new KDNotificationView
          title : "Select a user first"

    migrateForm = @modalTabs.forms["Migrate Kodingen Users"]

    KD.remote.api.JOldUser.__currentState (res)->
      migrateForm.inputs.currentState.updatePartial res
