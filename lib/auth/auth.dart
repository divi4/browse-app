class User {
  String username;
  bool userConfirmed;
  bool sessionValid;
  String? userSub;
  Map<String, dynamic> claims;
  final String idToken;
  final String accessToken;

  User(this.username, this.userConfirmed, this.sessionValid, this.userSub,
      this.claims, this.idToken, this.accessToken);
}