import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:postreal/data/auth_methods.dart';
import 'package:postreal/data/models/comment.dart';
import 'package:postreal/data/models/notification.dart';
import 'package:postreal/data/models/post.dart';
import 'package:postreal/data/models/user.dart' as model;
import 'package:postreal/data/storage_methods.dart';
import 'package:uuid/uuid.dart';

class FirestoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthMethods _authMethods = AuthMethods();

  //function to mark unread notifications as read
  Future<void> markNotificationsAsRead() async {
    final notificationsRef = _firestore
        .collection('notifications')
        .doc(_authMethods.auth.currentUser!.uid)
        .collection('userNotifications');
    final batch = _firestore.batch();
    final querySnapshot =
        await notificationsRef.where('isRead', isEqualTo: false).get();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // function to get stream of user's notifications
  Stream notificationStream() {
    final user = _authMethods.auth.currentUser!;
    return _firestore
        .collection('notifications')
        .doc(user.uid)
        .collection('userNotifications')
        .orderBy('timeStamp', descending: true)
        .snapshots();
  }

  //function to create new notification
  Future<void> addNotificationToReceiver(
      {required UserNotification notification,
      required String receiverId}) async {
    await _firestore
        .collection('notifications')
        .doc(receiverId)
        .collection('userNotifications')
        .add(notification.toJson());
  }

  //function to delete all notifications of a user
  Future<void> deleteAllNotifications() async {
    final notificationDocs = await _firestore
        .collection('notifications')
        .doc(_authMethods.auth.currentUser!.uid)
        .collection('userNotifications')
        .get();

    final batch = _firestore.batch();

    for (var doc in notificationDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // function to add new post/photo
  Future<String> addNewPost({
    required File img,
    String? caption,
    required model.User user,
  }) async {
    try {
      // to upload new picture
      String pictureUrl = await StorageMethods()
          .uploadImageToStorage(childName: "postPics", img: img, isPost: true);

      // after uploading picture,
      // need to create a post that contains pic and caption
      Post post = Post(
        caption: "${caption?.trim()}",
        uid: user.uid,
        likes: [],
        username: user.username.trim(),
        datePublished: DateTime.now(),
        profilePicUrl: user.profilePicUrl,
        postPicUrl: pictureUrl,
        postId: const Uuid().v1(),
      );
      await _firestore.collection('posts').doc(post.postId).set(post.toJson());
      return "success";
    } catch (err) {
      return err.toString().replaceAll(RegExp(r'\[[^\]]+\]'), '');
    }
  }

  // function to update username
  // not using try/catch here because it will be taken care in the editprofile_bloc
  Future<bool> updateUsername(
      String newUsername, String oldUsername, String userId) async {
    if (newUsername == oldUsername) {
      return true;
    }
    if (await _authMethods.usernameExits(newUsername)) {
      return false;
    }
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'username': newUsername});
    return true;
  }

  // function to update username
  Future<bool> updateBio(String newBio, String oldBio, String userId) async {
    if (newBio == oldBio) {
      return true;
    }
    await _firestore.collection('users').doc(userId).update({'bio': newBio});
    return true;
  }

  // function to like or unlike a post
  Future<bool> likeUnlikePost(String postId, String likerId, List likes,
      String posterId, String postPicUrl) async {
    try {
      if (likes.contains(likerId)) {
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayRemove([likerId]),
        });
      } else {
        await _firestore.collection('posts').doc(postId).update({
          'likes': FieldValue.arrayUnion([likerId]),
        });
        // after liking, we also need to add notification to receiver
        if (likerId != posterId) {
          model.User liker = await _authMethods.getUserDetails();
          UserNotification notification = UserNotification(
              senderId: likerId,
              senderUsername: liker.username,
              senderProfilePic: liker.profilePicUrl,
              notificationType: "like",
              timeStamp: DateTime.now(),
              postId: postId,
              postPicUrl: postPicUrl);
          await addNotificationToReceiver(
              notification: notification, receiverId: posterId);
        }
      }
    } catch (err) {
      return false;
    }
    return true;
  }

  // function to follow user
  Future<void> followUser({
    required String stalkedPersonId,
    required String stalkerId,
  }) async {
    DocumentReference stalkedPersonRef =
        _firestore.collection('users').doc(stalkedPersonId);
    DocumentReference stalkerRef =
        _firestore.collection('users').doc(stalkerId);
    WriteBatch batch = _firestore.batch();
    batch.update(stalkedPersonRef, {
      'followers': FieldValue.arrayUnion([stalkerId])
    });
    batch.update(stalkerRef, {
      'following': FieldValue.arrayUnion([stalkedPersonId])
    });
    await batch.commit();

    // after following, need to send notification
    model.User follower = await _authMethods.getUserDetails();
    UserNotification notification = UserNotification(
      senderId: stalkerId,
      senderUsername: follower.username,
      senderProfilePic: follower.profilePicUrl,
      notificationType: "follow",
      timeStamp: DateTime.now(),
    );
    await addNotificationToReceiver(
        notification: notification, receiverId: stalkedPersonId);
  }

  // function to unfollow user
  Future<void> unFollowUser({
    required String stalkedPersonId,
    required String stalkerId,
  }) async {
    DocumentReference stalkedPersonRef =
        _firestore.collection('users').doc(stalkedPersonId);
    DocumentReference stalkerRef =
        _firestore.collection('users').doc(stalkerId);
    WriteBatch batch = _firestore.batch();
    batch.update(stalkedPersonRef, {
      'followers': FieldValue.arrayRemove([stalkerId])
    });
    batch.update(stalkerRef, {
      'following': FieldValue.arrayRemove([stalkedPersonId])
    });
    await batch.commit();
  }

  // function to comment on post
  Future<String> commentOnPost(
      {required String postId,
      required String text,
      required String commentatorId,
      required String posterId,
      required String username,
      required String profilePicUrl,
      required String postPicUrl}) async {
    try {
      Comment comment = Comment(
          text: text.trim(),
          commentId: const Uuid().v1(),
          commentatorProfilePicUrl: profilePicUrl,
          commentatorUsername: username,
          commentatorId: commentatorId,
          dateCommented: DateTime.now());
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(comment.commentId)
          .set(comment.toJson());

      // after commenting, we need to add a comment notification
      if (commentatorId != posterId) {
        UserNotification notification = UserNotification(
            senderId: commentatorId,
            senderUsername: username,
            senderProfilePic: profilePicUrl,
            notificationType: "comment",
            timeStamp: DateTime.now(),
            postId: postId,
            postPicUrl: postPicUrl);
        await addNotificationToReceiver(
            notification: notification, receiverId: posterId);
      }

      return "success";
    } catch (err) {
      return err.toString().replaceAll(RegExp(r'\[[^\]]+\]'), '');
    }
  }

  //function to delete a comment on a post
  Future<String> deleteComment(
      {required String postId, required String commentId}) async {
    String result;
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();
      result = "Comment successfully deleted.";
    } catch (err) {
      result = err.toString().replaceAll(RegExp(r'\[[^\]]+\]'), '');
    }
    return result;
  }

  // function to delete a post
  Future<String> deletePost({required String postId}) async {
    String result;
    try {
      await _firestore.collection('posts').doc(postId).delete();
      result = "Post successfully deleted.";
    } catch (err) {
      result = err.toString().replaceAll(RegExp(r'\[[^\]]+\]'), '');
    }
    return result;
  }
}
