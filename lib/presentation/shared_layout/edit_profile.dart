import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:postreal/business_logic/editprofile_bloc/editprofile_bloc.dart';
import 'package:postreal/presentation/shared_layout/home_screen.dart';
import 'package:postreal/utils/validator.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  final String username;
  final String bio;
  final String userId;

  const EditProfileScreen(
      {super.key,
      required this.username,
      required this.bio,
      required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _updateProfileKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    _usernameController.dispose();
    _bioController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editProfileBloc = Provider.of<EditProfileBloc>(context);
    final editProfileState = editProfileBloc.state;
    _usernameController.text = widget.username;
    _bioController.text = widget.bio;
    if (editProfileState is ProfileUpdatedState) {
      Fluttertoast.showToast(msg: "Updated");
      return const HomeScreen();
    } else if (editProfileState is UpdateErrorState) {
      Fluttertoast.showToast(msg: editProfileState.message!);
    }
    return Material(
        child: SafeArea(
            child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Form(
              key: _updateProfileKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      return TextFieldValidator.validateUsername(value);
                    },
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(labelText: "Username"),
                  ),
                  TextFormField(
                    controller: _bioController,
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      return TextFieldValidator.bioValidator(value);
                    },
                    maxLines: 3,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(labelText: "Bio"),
                  ),
                ],
              )),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () {
                  if (_updateProfileKey.currentState!.validate()) {
                    final String newUsername = _usernameController.text.trim();
                    final String newBio = _bioController.text.trim();
                    // when user makes no changes in fields
                    if (newUsername == widget.username &&
                        newBio == widget.bio) {
                      Navigator.pop(context);
                    }
                    // when there is new info, we need to update info
                    else {
                      editProfileBloc.add(EditClickedEvent(
                          newUsername: newUsername,
                          newBio: newBio,
                          oldUsername: widget.username,
                          oldBio: widget.bio,
                          userId: widget.userId));
                    }
                  }
                },
                child: (editProfileState is EditProfileProcessing)
                    ? const LinearProgressIndicator()
                    : const Text("Update")),
          ),
          TextButton(
              onPressed: (editProfileState is EditProfileProcessing)
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text("Dissmiss"))
        ],
      ),
    )));
  }
}
