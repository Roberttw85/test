import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  Image,
} from 'react-native';
import { useImages } from '../context/ImageContext';

const HomeScreen = ({ navigation }) => {
  const { targetImage, candidateImages, resetAll } = useImages();

  const canAnalyze = targetImage && candidateImages.length > 0;

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Jigsaw Solver</Text>
        <Text style={styles.subtitle}>
          Find the perfect puzzle piece match
        </Text>
      </View>

      <View style={styles.content}>
        {/* Target Image Section */}
        <TouchableOpacity
          style={[styles.card, targetImage && styles.cardComplete]}
          onPress={() => navigation.navigate('TargetImage')}
        >
          <View style={styles.cardIcon}>
            {targetImage ? (
              <Image source={{ uri: targetImage.uri }} style={styles.thumbnail} />
            ) : (
              <Text style={styles.iconText}>1</Text>
            )}
          </View>
          <View style={styles.cardContent}>
            <Text style={styles.cardTitle}>Target Image</Text>
            <Text style={styles.cardDescription}>
              {targetImage
                ? 'Target uploaded - Tap to change'
                : 'Upload the empty puzzle hole'}
            </Text>
          </View>
          <Text style={styles.arrow}>{targetImage ? '✓' : '→'}</Text>
        </TouchableOpacity>

        {/* Candidate Images Section */}
        <TouchableOpacity
          style={[
            styles.card,
            candidateImages.length === 10 && styles.cardComplete,
          ]}
          onPress={() => navigation.navigate('CandidateImages')}
        >
          <View style={styles.cardIcon}>
            <Text style={styles.iconText}>2</Text>
          </View>
          <View style={styles.cardContent}>
            <Text style={styles.cardTitle}>Candidate Pieces</Text>
            <Text style={styles.cardDescription}>
              {candidateImages.length > 0
                ? `${candidateImages.length}/10 pieces uploaded`
                : 'Upload up to 10 puzzle pieces'}
            </Text>
          </View>
          <Text style={styles.arrow}>
            {candidateImages.length === 10 ? '✓' : '→'}
          </Text>
        </TouchableOpacity>

        {/* Analyze Button */}
        <TouchableOpacity
          style={[styles.analyzeButton, !canAnalyze && styles.analyzeButtonDisabled]}
          onPress={() => canAnalyze && navigation.navigate('Results')}
          disabled={!canAnalyze}
        >
          <Text style={styles.analyzeButtonText}>
            {canAnalyze ? 'Analyze & Find Match' : 'Upload images to continue'}
          </Text>
        </TouchableOpacity>

        {/* Reset Button */}
        {(targetImage || candidateImages.length > 0) && (
          <TouchableOpacity style={styles.resetButton} onPress={resetAll}>
            <Text style={styles.resetButtonText}>Reset All</Text>
          </TouchableOpacity>
        )}
      </View>

      <View style={styles.footer}>
        <Text style={styles.footerText}>
          Powered by color & geometry analysis
        </Text>
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
    paddingTop: 40,
    paddingBottom: 24,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#1a1a2e',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
  },
  content: {
    flex: 1,
    paddingHorizontal: 24,
  },
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 20,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 3,
  },
  cardComplete: {
    borderColor: '#4CAF50',
    borderWidth: 2,
  },
  cardIcon: {
    width: 50,
    height: 50,
    borderRadius: 12,
    backgroundColor: '#e8f0fe',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
    overflow: 'hidden',
  },
  iconText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#4285f4',
  },
  thumbnail: {
    width: '100%',
    height: '100%',
  },
  cardContent: {
    flex: 1,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1a1a2e',
    marginBottom: 4,
  },
  cardDescription: {
    fontSize: 14,
    color: '#666',
  },
  arrow: {
    fontSize: 20,
    color: '#4285f4',
  },
  analyzeButton: {
    backgroundColor: '#4285f4',
    borderRadius: 12,
    padding: 18,
    alignItems: 'center',
    marginTop: 16,
  },
  analyzeButtonDisabled: {
    backgroundColor: '#ccc',
  },
  analyzeButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '600',
  },
  resetButton: {
    padding: 16,
    alignItems: 'center',
    marginTop: 8,
  },
  resetButtonText: {
    color: '#ff5252',
    fontSize: 16,
  },
  footer: {
    paddingHorizontal: 24,
    paddingVertical: 16,
    alignItems: 'center',
  },
  footerText: {
    fontSize: 12,
    color: '#999',
  },
});

export default HomeScreen;
