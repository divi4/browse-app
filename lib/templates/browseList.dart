import 'package:flutter/material.dart';
import 'dart:math';

class BrowseTileList extends StatefulWidget {
  const BrowseTileList({
    super.key, 
    required this.browses, 
    required this.quantities, 
    this.fontColor = Colors.black
  });
  
  final List<String> browses;
  final List<int> quantities;
  final Color fontColor;

  @override
  State<BrowseTileList> createState() => _BrowseTileList();
 }

class _BrowseTileList extends State<BrowseTileList> {
  @override
  Widget build(BuildContext context) {
    // Bool that checks if browse list is Greater Than two
    bool isBrowseGTTwo = widget.browses.length > 2 ? true : false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gets the smallest of either the browses or 2 to ensure only a max of two browse are listed on the requestTile
            // Quantities and Browses length should always be the same but this is to handle in case it doesn't
            for (int i = 0; i < min(min(widget.browses.length, widget.quantities.length), 2); i++)
              Text(
                '${widget.quantities[i]}x ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.fontColor,
                )
              )
          ],
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gets the smallest of either the browses or 2 to ensure only a max of two browse are listed on the requestTile
              // Quantities and Browses length should always be the same but this is to handle in case it doesn't
              for (int i = 0; i < min(min(widget.browses.length, widget.quantities.length), 2); i++)
                Text(
                  // Checks if there's more than 2 browse listed adding an elipse to the second one to indicate there's more  on the requestTile
                  (isBrowseGTTwo && i == 1)
                  ? '${widget.browses[i]}...'
                  : '${widget.browses[i]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.fontColor,
                  )
                ),
            ],
          ),
        ),
      ]
    );
  }
}

class BrowseQuantityList extends StatefulWidget {
  const BrowseQuantityList({
    super.key, 
    required this.browses, 
    required this.quantities,
    required this.types,
    this.fontColor = Colors.black
  });
  
  final List<String> browses;
  final List<int> quantities;
  final List<String> types;
  final Color fontColor;

  @override
  State<BrowseQuantityList> createState() => _BrowseQuantityList();
 }

class _BrowseQuantityList extends State<BrowseQuantityList> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantities, Browses and Types length should always be the same but this is to handle in case it doesn't
            for (int i = 0; i < min(min(widget.browses.length, widget.quantities.length), widget.types.length); i++)
              Text(
                '${widget.quantities[i]}x ',
                style: TextStyle(
                  color: widget.fontColor,
                )
              )
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantities, Browses and Types length should always be the same but this is to handle in case it doesn't
            for (int i = 0; i < min(min(widget.browses.length, widget.quantities.length), widget.types.length); i++)
              SelectableText(
                '${widget.browses[i]} ${widget.types[i]}',
                style: TextStyle(
                  color: widget.fontColor,
                )
              ),
          ],
        ),
      ]
    );
  }
}