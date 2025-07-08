import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'Staff.dart';

class StaffProfileView extends StatefulWidget {
  final Staff staff;
  final VoidCallback onEditPressed;

  const StaffProfileView({
    Key? key,
    required this.staff,
    required this.onEditPressed,
  }) : super(key: key);

  @override
  _StaffProfileViewState createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Staff Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: widget.onEditPressed,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            SizedBox(height: 24),
            _buildInfoSection(),
            SizedBox(height: 24),
            _buildDocumentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: widget.staff.profileImage.isNotEmpty
                ? NetworkImage(_getDirectImageUrl(widget.staff.profileImage))
                : AssetImage('assets/default_profile.png') as ImageProvider,
          ),
          SizedBox(height: 16),
          Text(
            widget.staff.name,

          ),
          Text(
            widget.staff.position,

          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',

            ),
            Divider(),
            _buildInfoRow('Staff ID', widget.staff.id),
            _buildInfoRow('Phone', widget.staff.phone),
            _buildInfoRow('Email', widget.staff.email),
            _buildInfoRow('NID', widget.staff.nid),
            _buildInfoRow(
              'Joining Date',
              widget.staff.joiningDate != null
                  ? DateFormat('dd/MM/yyyy').format(widget.staff.joiningDate!)
                  : 'Not available',
            ),
            _buildInfoRow('Salary', '\$${widget.staff.salary}'),
            SizedBox(height: 16),
            Text(
              'Address Information',

            ),
            Divider(),
            _buildInfoRow('Present Address', widget.staff.presentAddress),
            _buildInfoRow('Permanent Address', widget.staff.permanentAddress),
            SizedBox(height: 16),
            Text(
              'Additional Information',

            ),
            Divider(),
            _buildInfoRow('Guardian Info', widget.staff.guardianInfo),
            _buildInfoRow('Additional Info', widget.staff.info),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    if (widget.staff.documents.isEmpty) return SizedBox();

    final docUrls = widget.staff.documents.split(',');

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documents',
            ),
            Divider(),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: docUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showFullScreenImage(docUrls[index]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _getDirectImageUrl(docUrls[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : 'Not provided'),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(_getDirectImageUrl(imageUrl)),
            ),
          ),
        ),
      ),
    );
  }

  String _getDirectImageUrl(String driveUrl) {
    final regExp = RegExp(r'file/d/([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(driveUrl);
    if (match != null && match.groupCount >= 1) {
      return 'https://drive.google.com/uc?export=view&id=${match.group(1)}';
    }
    return driveUrl;
  }
}