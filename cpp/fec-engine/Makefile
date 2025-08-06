CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O3 -march=native
INCLUDES = -I./include -I./src
LIBS = -lpthread -lcrypto

# Directories
SRC_DIR = src
OBJ_DIR = obj
BIN_DIR = bin
INCLUDE_DIR = include

# Source files
SOURCES = $(wildcard $(SRC_DIR)/*.cpp)
OBJECTS = $(SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

# Target executable
TARGET = $(BIN_DIR)/fec-engine

# Default target
all: $(TARGET)

# Create directories
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Compile object files
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

# Link executable
$(TARGET): $(OBJECTS) | $(BIN_DIR)
	$(CXX) $(OBJECTS) -o $@ $(LIBS)

# Test target
test: $(TARGET)
	./$(TARGET) --test

# Benchmark target
benchmark: $(TARGET)
	./$(TARGET) --benchmark

# Clean
clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR)

# Install
install: $(TARGET)
	sudo cp $(TARGET) /usr/local/bin/
	sudo cp include/*.h /usr/local/include/sdwan-fec/

# Uninstall
uninstall:
	sudo rm -f /usr/local/bin/fec-engine
	sudo rm -rf /usr/local/include/sdwan-fec

.PHONY: all test benchmark clean install uninstall 