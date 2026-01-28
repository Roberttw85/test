import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  SafeAreaView,
  ScrollView,
  Alert,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useImages } from '../context/ImageContext';

const CandidateImagesScreen = ({ navigation }) => {
  const { candidateImages, addCandidateImage, removeCandidateImage, targetImage } = useImages();

  const pickImage = async (useCamera = false) => {
    if (candidateImages.length >= 10) {
      Alert.alert('Limit Reached', 'You can only upload up to 10 candidate images.');
      return;
    }

    try {
      let result;

      if (useCamera) {
        const cameraPermission = await ImagePicker.requestCameraPermissionsAsync();
        if (!cameraPermission.granted) {
          Alert.alert('Permission Required', 'Camera permission is required to take photos.');
          return;
        }
        result = await ImagePicker.launchCameraAsync({
          mediaTypes: ['images'],
          allowsEditing: true,
          aspect: [1, 1],
          quality: 0.8,
        });
      } else {
        const mediaLibraryPermission = await ImagePicker.requestMediaLibraryPermissionsAsync();
        if (!mediaLibraryPermission.granted) {
          Alert.alert('Permission Required', 'Photo library permission is required.');
          return;
        }
        result = await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ['images'],
          allowsEditing: true,
          aspect: [1, 1],
          quality: 0.8,
        });
      }

      if (!result.canceled && result.assets[0]) {
        addCandidateImage({
          uri: result.assets[0].uri,
          width: result.assets[0].width,
          height: result.assets[0].height,
        });
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to pick image. Please try again.');
    }
  };

  const showImageOptions = () => {
    Alert.alert('Add Puzzle Piece', 'Choose how to add your candidate image', [
      { text: 'Take Photo', onPress: () => pickImage(true) },
      { text: 'Choose from Library', onPress: () => pickImage(false) },
      { text: 'Cancel', style: 'cancel' },
    ]);
  };

  const confirmRemove = (id) => {
    Alert.alert('Remove Image', 'Are you sure you want to remove this image?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Remove', style: 'destructive', onPress: () => removeCandidateImage(id) },
    ]);
  };

  const canContinue = targetImage && candidateImages.length > 0;

  const renderGridItem = (index) => {
    const image = candidateImages[index];

    if (image) {
      return (
        <TouchableOpacity
          key={image.id}
          style={styles.gridItem}
          onLongPress={() => confirmRemove(image.id)}
        >
          <Image source={{ uri: image.uri }} style={styles.gridImage} />
          <View style={styles.gridNumber}>
            <Text style={styles.gridNumberText}>{index + 1}</Text>
          </View>
          <TouchableOpacity
            style={styles.removeButton}
            onPress={() => confirmRemove(image.id)}
          >
            <Text style={styles.removeButtonText}>×</Text>
          </TouchableOpacity>
        </TouchableOpacity>
      );
    }

    return (
      <TouchableOpacity
        key={`empty-${index}`}
        style={[styles.gridItem, styles.gridItemEmpty]}
        onPress={showImageOptions}
      >
        <Text style={styles.addIcon}>+</Text>
        <Text style={styles.addText}>{index + 1}</Text>
      </TouchableOpacity>
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Candidate Pieces</Text>
        <Text style={styles.subtitle}>
          Upload up to 10 puzzle pieces to find the best match
        </Text>
        <View style={styles.counter}>
          <Text style={styles.counterText}>
            {candidateImages.length}/10 pieces added
          </Text>
        </View>
      </View>

      <ScrollView style={styles.content} contentContainerStyle={styles.scrollContent}>
        <View style={styles.grid}>
          {Array.from({ length: 10 }).map((_, index) => renderGridItem(index))}
        </View>

        <Text style={styles.hint}>
          Long press or tap × to remove an image
        </Text>
      </ScrollView>

      <View style={styles.actions}>
        <TouchableOpacity
          style={[styles.analyzeButton, !canContinue && styles.analyzeButtonDisabled]}
          onPress={() => canContinue && navigation.navigate('Results')}
          disabled={!canContinue}
        >
          <Text style={styles.analyzeButtonText}>
            {canContinue
              ? 'Analyze & Find Match'
              : targetImage
              ? 'Add at least 1 piece'
              : 'Upload target image first'}
          </Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f7fa',
  },
  header: {
    paddingHorizontal: 24,
    paddingTop: 20,
    paddingBottom: 16,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a1a2e',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 15,
    color: '#666',
    lineHeight: 22,
  },
  counter: {
    marginTop: 12,
    backgroundColor: '#e8f0fe',
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
  },
  counterText: {
    color: '#4285f4',
    fontWeight: '600',
    fontSize: 14,
  },
  content: {
    flex: 1,
  },
  scrollContent: {
    paddingHorizontal: 24,
    paddingBottom: 24,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  gridItem: {
    width: '48%',
    aspectRatio: 1,
    marginBottom: 16,
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 6,
    elevation: 3,
  },
  gridItemEmpty: {
    borderWidth: 2,
    borderColor: '#e0e0e0',
    borderStyle: 'dashed',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fafafa',
    shadowOpacity: 0,
    elevation: 0,
  },
  gridImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  gridNumber: {
    position: 'absolute',
    bottom: 8,
    left: 8,
    backgroundColor: 'rgba(0,0,0,0.6)',
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  gridNumberText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  removeButton: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: 'rgba(255,82,82,0.9)',
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  removeButtonText: {
    color: '#fff',
    fontSize: 20,
    fontWeight: 'bold',
    marginTop: -2,
  },
  addIcon: {
    fontSize: 32,
    color: '#4285f4',
  },
  addText: {
    fontSize: 14,
    color: '#999',
    marginTop: 4,
  },
  hint: {
    textAlign: 'center',
    color: '#999',
    fontSize: 13,
    marginTop: 8,
  },
  actions: {
    paddingHorizontal: 24,
    paddingVertical: 16,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    backgroundColor: '#fff',
  },
  analyzeButton: {
    backgroundColor: '#4285f4',
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
  },
  analyzeButtonDisabled: {
    backgroundColor: '#ccc',
  },
  analyzeButtonText: {
    color: '#fff',
    fontSize: 17,
    fontWeight: '600',
  },
});

export default CandidateImagesScreen;
