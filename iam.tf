# Creating IAM User

resource "aws_iam_user" "kops-user" {
  name = "kops-user"
}

resource "aws_iam_access_key" "kop-user-access-key" {
  user = aws_iam_user.kops-user.id
}

resource "aws_iam_group" "kops-group" {
  name = "kops-group"
}

resource "aws_iam_user_group_membership" "member-user-group" {
  user = aws_iam_user.kops-user.name
  groups = [aws_iam_group.kops-group.name]
}

resource "aws_iam_group_policy_attachment" "s3-attach" {
  group      = aws_iam_group.kops-group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_group_policy_attachment" "ec2-attach" {
  group      = aws_iam_group.kops-group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}
resource "aws_iam_group_policy_attachment" "events-attach" {
  group      = aws_iam_group.kops-group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"
}
resource "aws_iam_group_policy_attachment" "iam-attach" {
  group      = aws_iam_group.kops-group.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}
resource "aws_iam_group_policy_attachment" "route53-attach" {
  group      = aws_iam_group.kops-group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}
resource "aws_iam_group_policy_attachment" "sqs-attach" {
  group      = aws_iam_group.kops-group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}
resource "aws_iam_group_policy_attachment" "vpc-attach" {
  group      = aws_iam_group.kops-group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}