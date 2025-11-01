import 'package:flutter/material.dart';

class CustomCarousel extends StatefulWidget {
  final List<Widget> items;
  final double height;
  final Color activeDotColor;
  final Color inactiveDotColor;

  const CustomCarousel({
    super.key,
    required this.items,
    this.height = 250,
    this.activeDotColor = Colors.amber,
    this.inactiveDotColor = Colors.grey,
  });

  @override
  State<CustomCarousel> createState() => _CustomCarouselState();
}

class _CustomCarouselState extends State<CustomCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  void _nextPage() {
    if (_currentIndex < widget.items.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Carousel
          PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) => widget.items[index],
          ),

          // Left arrow
          Positioned(
            bottom:0,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white,size: 40,),
              onPressed: _previousPage,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                shape: const CircleBorder(),
              ),
            ),
          ),

          // Right arrow
          Positioned(
            bottom:0,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white,size: 40,),
              onPressed: _nextPage,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                shape: const CircleBorder(),
              ),
            ),
          ),

          // Dots indicator
          Positioned(
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.items.length, (index) {
                bool isActive = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal:  10),
                  width: isActive ? 20 : 18,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isActive
                        ? widget.activeDotColor
                        : widget.inactiveDotColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
