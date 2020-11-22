$(function () {
    const socket = io("/core");
    const imgid = Math.floor(Math.random() * Math.floor(16));

    let chat_socket = null;
    let me = null;

    socket.on('connect_error', function (err) {
        console.error(`Connect core error: ${err}`);
        alertMessage('danger', 'Core connect error', err);
    });
    socket.on('error', function (err) {
        console.error(`Core error: ${err}`);
        alertMessage('danger', 'Core error', err);
    });

    // Display alerts
    function alertMessage(level, prefix, message) {
        var alert = `
        <div class="alert alert-${level} alert-dismissible fade show" role="alert">
            <strong>${prefix}:</strong> ${message}
            <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
            </button>
        </div>`;

        $('.alert-message').append(alert);
        $('.alert').alert();
    };

    // Add user to users list
    function addUser(user) {
        let user_entry = `
        <li data-uid=${user.uid} data-nickname=${user.nickname}>
            <div class="d-flex bd-highlight">
                <div class="img_cont">
                    <img src="/img/avatar${user.imgid}.png" class="rounded-circle user_img">
                    <span class="status_icon ${user.status}"></span>
                </div>
                <div class="user_info">
                    <span>${user.nickname}</span>
                    <p>${user.status}</p>
                </div>
            </div>
        </li >`;
        $('.contacts').append(user_entry);
    }

    // Add message to chat application
    function addMessage(message) {
        if (message.nickname === me.nickname) {
            side = 'justify-content-end';
        } else {
            side = 'justify-content-start';
        }
        var msg_entry = `<div class="d-flex ${side} mb-4">
            <div class="img_cont_msg">
                <img src="/img/avatar${message.imgid}.png"
                    class="rounded-circle user_img_msg">
                            </div>
                <div class="msg_cotainer">
                    ${message.text}
                    <span class="msg_time">${message.date}</span>
                </div>
            </div>`;
        $('.application .msg_card_body').append(msg_entry);
    }

    // Set main dialogue with user selected
    function speakTo(params) {
        // Update Header
        $('#chat_messages .msg_head .img_cont img').attr('src', params.image);
        $('#chat_messages .msg_head .user_info span').text(`Chat with ${params.nickname}`);
        $('#chat_messages .msg_head .user_info p').text(`${params.nb_messages} messages`);
        // Remove all messages from previous discussions
        $('#chat_messages .msg_card_body').html('');
        // Display messages
        $('#chat_messages').show();

        chat_socket.emit('speak', params.nickname);
    }

    // Update user status
    function updateStatus(nickname, status) {
        $(`#chat_users .contacts li[data-nickname='${nickname}'] .user_info p`).text(status);
        $(`#chat_users .contacts li[data-nickname='${nickname}'] .status_icon`).removeClass(['online', 'offline', 'away']).addClass(status);
    }

    // Switch from register to chat application
    function enterChat(user) {
        console.log(`Enter chat with nickname: ${user.nickname}`);

        // Reset errors
        $('.alert-message').html('');
        // Hide modal
        $('#register-modal').modal('hide');

        // Start authentified chat connection
        chat_socket = io("/chat", { auth: { token: user.uid } });

        // Chat events
        chat_socket.on('connect_error', function (err) {
            console.error(`Connect chat error: ${err}`);
            alertMessage('danger', 'Chat connect error', err);
        });
        // New person enter the chat
        chat_socket.on('hello', function (user) {
            addUser(user);
        });
        // Person status has changed
        chat_socket.on('status', function (data) {
            console.log(`${data.user} is ${data.status}`);
            updateStatus(data.user, data.status);
        });
        // On new message
        chat_socket.on('message', function (data) {
            console.log("Message " + data);
            addMessage(data);
        });
        chat_socket.on('message count', function (data) {
            console.log("Message count " + data);
            $(`#chat_messages .user_info p]`).text(`${data.count} Messages`);
        });
        // On disconnect remove from user list
        chat_socket.on('logout', function (nickname) {
            console.log("Logout " + nickname);
            $(`#chat_users .contacts li[data-nickname='${nickname}']`).remove();
        });

        // Announce entry to all users
        chat_socket.emit('enter', user);

        // retrieve users list
        chat_socket.emit('list', null, (response) => {
            if (response.error) {
                alertMessage('danger', 'Sorry', response.error);
                return false;
            }
            for (var uid in response) {
                if (me && me.uid === uid) { continue }
                addUser(response[uid]);
            }
        });

        // Display app
        $('.application').show();

        // Click on users activate chat room
        $(`#chat_users .contacts li`).on('click', function (e) {
            e.preventDefault();

            $('.contacts li').removeClass('active');
            $(this).addClass('active');
            nickname = $(this).data('nickname');

            console.log(`Chat with ${nickname}`);
            if (nickname === me.nickname) {
                alertMessage('danger', 'Sorry', 'you do not need a chat application to speak with yourself');
                return false;
            }

            speakTo({
                nickname: nickname,
                image: $(this).child('img').attr('src'),
                nb_messages: 0
            });
            return false;
        });

        // On message send add it to message list
        $('#sender_form').submit(function (e) {
            e.preventDefault(); // prevents page reloading
            chat_socket.emit('message', $('#message').text());
            $('#message').text('');
            return false;
        });
    };

    // On register hide modal
    $('#register-form').submit(function (e) {
        e.preventDefault();
        nickname = $('#nickname').val();
        socket.emit('register', { nickname: nickname, imgid: imgid }, (response) => {
            if (response.error) {
                alertMessage('danger', 'Sorry', response.error);
                return false;
            }
            me = response;
            addUser(response);
            enterChat(response);
        });
        return false;
    });

    // Search user from user list

    // Auto-logout on exit
    $(window).on("unload", function () {
        if (chat_socket) { chat_socket.emit('logout'); }
    });
    // On page focus in set online status
    $(window).on("focus", function () {
        if (chat_socket) { chat_socket.emit('status', 'online'); }
        if (me) { updateStatus(me.nickname, 'online'); }
    });
    // On page focus out set offline status
    $(window).on("blur", function () {
        if (chat_socket) { chat_socket.emit('status', 'away'); }
        if (me) { updateStatus(me.nickname, 'away'); }
    });

    // Start with modal register only
    $('#register-modal').modal('show');

    // Setup a random picture
    $('#register-modal .avatar').attr('src', '/img/avatar' + imgid + '.png');
});