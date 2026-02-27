import 'package:flutter/material.dart';

class CustomerTypePage extends StatefulWidget {
  const CustomerTypePage({super.key});

  @override
  State<CustomerTypePage> createState() => _CustomerTypePageState();
}

class _CustomerTypePageState extends State<CustomerTypePage> {
  String? _selectedCustomerType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(),

                SizedBox(height: 40),

                // Customer Type Selection Cards
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Normal Customer Card
                      _buildCustomerTypeCard(
                        title: "Normal Customer",
                        description: "One-time service users",
                        icon: Icons.person_outline,
                        isSelected: _selectedCustomerType == "normal",
                        onTap: () {
                          setState(() {
                            _selectedCustomerType = "normal";
                          });
                        },
                      ),

                      SizedBox(height: 20),

                      // AMC Customer Card
                      _buildCustomerTypeCard(
                        title: "AMC Customer",
                        description: "Annual Maintenance Contract holders",
                        icon: Icons.assignment_outlined,
                        isSelected: _selectedCustomerType == "amc",
                        onTap: () {
                          setState(() {
                            _selectedCustomerType = "amc";
                          });
                        },
                      ),

                      SizedBox(height: 40),

                      // Continue Button
                      _buildContinueButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 28,
          ),
        ),

        SizedBox(height: 20),

        Text(
          "Select Customer Type",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),

        SizedBox(height: 12),

        Text(
          "Choose your customer type to continue with our services",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.15)
              : Theme.of(context).colorScheme.onPrimary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withOpacity(0.5),
                  width: 2,
                )
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 30,
              ),
            ),

            SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    description,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Selection Indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _selectedCustomerType != null
            ? () {
                // Handle navigation based on selected customer type
                // _handleCustomerTypeSelection();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).cardColor,
          foregroundColor: Theme.of(context).primaryColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        child: Text("Continue"),
      ),
    );
  }

}
