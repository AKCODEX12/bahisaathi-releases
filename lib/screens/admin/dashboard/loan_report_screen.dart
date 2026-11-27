import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LoanReportScreen extends StatefulWidget {
  final List<String> loanIds;
  final String customerName;
  final String customerEmail;

  const LoanReportScreen({
    super.key,
    required this.loanIds,
    required this.customerName,
    required this.customerEmail,
  });

  @override
  State<LoanReportScreen> createState() =>
      _LoanReportScreenState();
}

class _LoanReportScreenState
    extends State<LoanReportScreen> {

  double totalAmount = 0;
  double totalInterest = 0;
  double totalPaid = 0;

  bool loading = true;

  List<Map<String, dynamic>> loans = [];

  @override
  void initState() {
    super.initState();
    loadReport();
  }


  Future<void> loadReport() async {

    try {

      for (String id in widget.loanIds) {

        final doc =
        await FirebaseFirestore.instance
            .collection('loans')
            .doc(id)
            .get();


        if (doc.exists) {

          final data =
          doc.data() as Map<String,dynamic>;

          loans.add(data);


          final amount =
              double.tryParse(
                data['amount']
                    .toString(),
              ) ?? 0;


          final interest =
              double.tryParse(
                data['interest']
                    .toString(),
              ) ?? 0;


          final paid =
              double.tryParse(
                data['paidAmount']
                    .toString(),
              ) ?? 0;


          totalAmount += amount;
          totalInterest += interest;
          totalPaid += paid;

        }

      }

    } catch(e){

      debugPrint(
        e.toString(),
      );

    }


    setState(() {
      loading=false;
    });

  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title:
        const Text(
          "Loan Report",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        backgroundColor:
        Colors.green,

        foregroundColor:
        Colors.white,

      ),


      body:

      loading

          ?

      const Center(
        child:
        CircularProgressIndicator(),
      )


          :

      SingleChildScrollView(

        padding:
        const EdgeInsets.all(16),

        child:

        Column(

          crossAxisAlignment:
          CrossAxisAlignment.start,


          children:[


            Card(

              child:
              ListTile(

                title:
                Text(
                  widget.customerName,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                subtitle:
                Text(
                  widget.customerEmail,
                ),

              ),

            ),



            const SizedBox(height:15),



            _summaryCard(
              "Total Loan Amount",
              totalAmount,
              Colors.blue,
            ),


            _summaryCard(
              "Total Interest",
              totalInterest,
              Colors.orange,
            ),


            _summaryCard(
              "Total Paid",
              totalPaid,
              Colors.green,
            ),


            _summaryCard(
              "Remaining",
              totalAmount +
                  totalInterest -
                  totalPaid,
              Colors.red,
            ),



            const SizedBox(height:20),



            const Text(
              "Loan Details",
              style:
              TextStyle(
                fontSize:18,
                fontWeight:
                FontWeight.bold,
              ),
            ),



            ...loans.map(
                  (loan)=>

                  Card(

                    child:
                    ListTile(

                      title:
                      Text(
                        loan['name']
                            ??
                            "Loan",
                      ),

                      subtitle:
                      Text(
                        "Amount : ₹${loan['amount']}\n"
                            "Status : ${loan['status']}",
                      ),

                    ),

                  ),

            ),



            const SizedBox(height:20),



            SizedBox(

              width:
              double.infinity,


              height:50,


              child:
              ElevatedButton.icon(

                onPressed:(){

                  debugPrint(
                    "PDF generation pending",
                  );

                },


                icon:
                const Icon(
                  Icons.picture_as_pdf,
                ),


                label:
                const Text(
                  "Generate PDF",
                ),

              ),

            )


          ],

        ),

      ),

    );

  }



  Widget _summaryCard(
      String title,
      double value,
      Color color,
      ){

    return Card(

      child:
      ListTile(

        leading:
        CircleAvatar(
          backgroundColor:
          color,

          child:
          const Icon(
            Icons.currency_rupee,
            color:
            Colors.white,
          ),

        ),

        title:
        Text(title),


        trailing:
        Text(

          "₹${value.toStringAsFixed(0)}",

          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
            fontSize:16,
          ),

        ),

      ),

    );

  }

}